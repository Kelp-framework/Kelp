package Kelp::Routes;

use Kelp::Base;

use Carp;
use Plack::Util;
use Kelp::Util;
use Kelp::Routes::Location;
use Try::Tiny;

our @CARP_NOT = qw(Kelp::Module::Routes);

attr base => '';    # the default is set by config module
attr rebless => 0;    # do not rebless app by default
attr pattern_obj => 'Kelp::Routes::Pattern';
attr fatal => 0;
attr routes => sub { [] };
attr names => sub { {} };

# Cache
attr cache => sub {
    my $self = shift;
    my %cache;

    Plack::Util::inline_object(
        get => sub { $cache{$_[0]} },
        set => sub { $cache{$_[0]} = $_[1] },
        clear => sub { %cache = () }
    );
};

sub add
{
    my ($self, $pattern, $descr, $parent) = @_;
    $parent = {} if !$parent || ref $parent ne 'HASH';

    my $route = $self->_parse_route($parent, $pattern, $descr);

    Kelp::Util::_DEBUG(routes => 'Added route: ', $route);

    return $self->_build_location($route);
}

sub clear
{
    my ($self) = @_;

    $self->routes([]);
    $self->cache->clear;
    $self->names({});
}

sub url
{
    my $self = shift;
    my $name = shift // croak "Route name is missing";
    my %args = @_ == 1 ? %{$_[0]} : @_;

    return $name unless exists $self->names->{$name};
    my $route = $self->routes->[$self->names->{$name}];
    return $route->build(%args);
}

sub _build_location
{
    # build a specific location object on which ->add can be called again
    my ($self, $route) = @_;

    return Kelp::Routes::Location->new(
        router => $self,
        parent => $route,
    );
}

sub _message
{
    my ($self, $type_str, @parts) = @_;
    my $message = "[ROUTES] $type_str: ";

    for my $part (@parts) {
        $part //= '';
        $part =~ s/ at .+? line \d+.\n//g;    # way prettier errors
    }

    return $message . join ' - ', @parts;
}

sub _error
{
    my ($self, @parts) = @_;

    croak $self->_message('ERROR', @parts) if $self->fatal;
    carp $self->_message('WARNING, route is skipped', @parts);
    return;
}

sub _warning
{
    my ($self, @parts) = @_;

    carp $self->_message('WARNING', @parts);
}

sub _parse_route
{
    my ($self, $parent, $key, $val) = @_;

    # Scalar, e.g. 'bar#foo'
    # CODE, e.g. sub { ... }
    if (!ref $val || ref $val eq 'CODE') {
        $val = {to => $val};
    }

    # Sanity check
    if (ref $val ne 'HASH') {
        return $self->_error('Route description must be a string, CODE or HASH');
    }

    # Handle key in form of [METHOD => 'pattern']
    if (ref $key eq 'ARRAY') {
        if ((grep { defined } @$key) != 2) {
            return $self->_error("Path as an ARRAY is expected to have two parameters");
        }

        my ($method, $pattern) = @$key;
        if (!grep { $method eq $_ } qw/GET POST PUT DELETE/) {
            $self->_warning("Using an odd method '$method'");
        }

        $val->{method} = $method;
        $key = $pattern;
    }

    # Only SCALAR and Regexp allowed
    if (ref $key && ref $key ne 'Regexp') {
        return $self->_error("Pattern '$key' can not be computed");
    }

    $val->{pattern} = $key;

    # Format and load the target of 'to'
    my $error;
    try {
        $val->{to} = $self->format_to($val->{to});
        $val->{dest} = $self->load_destination($val->{to});
    }
    catch {
        $error = $_;
    };

    if (!defined $val->{dest} || $error) {
        return $self->_error("Invalid destination for route '$key'", $error);
    }

    # store tree for later and set up bridge based on it
    my $tree = delete $val->{tree};
    if ($tree && (ref $tree ne 'ARRAY' || @$tree % 2 != 0)) {
        return $self->_error("Tree must be an even-sized ARRAY");
    }
    $val->{bridge} ||= defined $tree;

    # psgi + bridge is incompatible, as psgi route will only render (not return true values)
    if ($val->{psgi} && $val->{bridge}) {
        return $self->_error("Route '$key' cannot have both 'psgi' and 'bridge'");
    }

    # Adjust the destination for psgi
    $val->{dest} = $self->wrap_psgi($val->{to}, $val->{dest})
        if $val->{psgi};

    # Credit stuff from tree parent, if possible
    if (defined $parent->{pattern}) {
        if ($val->{name} && $parent->{name}) {
            $val->{name} = $parent->{name} . '_' . $val->{name};
        }
        $val->{pattern} = $parent->{pattern} . $val->{pattern};
    }

    # Can now add the object to routes
    my $route = $self->build_pattern($val);
    push @{$self->routes}, $route;

    # Add route index to names
    if (my $name = $val->{name}) {
        if (exists $self->names->{$name}) {
            $self->_warning("Multiple routes named '$name'");
        }
        $self->names->{$name} = $#{$self->routes};
    }

    # handle further tree levels, if any
    $tree //= [];
    while (@$tree) {
        my ($k, $v) = splice(@$tree, 0, 2);
        $self->_parse_route($val, $k, $v);
    }

    return $route;
}

# Override to change what 'to' values are valid
sub format_to
{
    my ($self, $to) = @_;
    my $ref = ref $to;

    if (!defined $to) {
        croak 'missing';
    }
    elsif (!$to || ($ref && $ref ne 'CODE')) {
        croak 'neither a string nor a coderef';
    }

    $to = Kelp::Util::camelize($to, $self->base)
        unless $ref;

    return $to;
}

# Override to change the way the application loads the destination from 'to'
sub load_destination
{
    my ($self, $to) = @_;
    my $ref = ref $to;

    if (!$ref && $to) {

        # Load the class, if there is one
        if (my $class = Kelp::Util::extract_class($to)) {
            my $method = Kelp::Util::extract_function($to);

            Kelp::Util::load_package($class);

            my $method_code = $class->can($method);
            croak "method '$method' does not exist in class '$class'"
                unless $method_code;

            return [$self->rebless && $class->isa($self->base) ? $class : undef, $method_code];
        }
        elsif (exists &$to) {

            # Move to reference
            return [undef, \&{$to}];
        }
        else {
            croak "function '$to' does not exist";
        }
    }
    elsif ($ref) {
        croak "don't know how to load from reftype '$ref'"
            unless $ref eq 'CODE';

        return [undef, $to];
    }

    return undef;
}

# Override to change the way a psgi application is adapted to kelp
sub wrap_psgi
{
    my ($self, $to, $destination) = @_;

    # adjust the subroutine to load
    # don't adjust the controller (index 0) to still call the proper hooks if
    # it was configured to be a controller action

    $destination->[1] = Kelp::Util::adapt_psgi($destination->[1]);
    return $destination;
}

# Override to use a custom pattern object
sub build_pattern
{
    return Kelp::Util::load_package($_[0]->pattern_obj)->new(
        %{$_[1]}
    );
}

sub match
{
    my ($self, $path, $method) = @_;
    $method //= '';

    # Look for this path and method in the cache. If found,
    # return the array of routes that matched the previous time.
    # If not found, then return all routes.
    my $key = "$path:$method";
    my $routes = $self->cache->get($key);
    if (!defined $routes) {

        # Look through all routes, grep the ones that match and sort them with
        # the compare method. Perl sort function is stable, meaning it will
        # preserve the initial order of records it considers equal. This means
        # that the order of registering routes is crucial when a couple of
        # routes are registered with the same pattern: routes defined earlier
        # will be run first and the first one to render will end the execution
        # chain.
        @$routes =
            sort { $a->compare($b) }
            grep { $_->match($path, $method) } @{$self->routes};

        $self->cache->set($key, $routes);
    }
    else {
        # matching fills the route parameters
        $_->match($path, $method) for @$routes;
    }

    # shallow copy to make sure nothing pollutes the cache
    return [@$routes];
}

# dispatch does not do many sanity checks on the destination, since those are
# done in format_to and load_destination. A single check is present, which
# lazy-computes dest if it is not set (since some code might have overrode add).
sub dispatch
{
    my ($self, $app, $route) = @_;
    $app || die "Application instance required";
    $route || die "No route pattern instance supplied";

    my $dest = $route->dest;
    $route->dest($self->load_destination($route->to))
        unless $dest;

    my ($controller, $action) = @{$dest};
    my $c = $app->context->set_controller($controller);

    $app->context->run_method(before_dispatch => ($route->to));
    return $action->($c, @{$route->param});
}

1;

__END__

=pod

=head1 NAME

Kelp::Routes - Routing for a Kelp app

=head1 SYNOPSIS

    use Kelp::Routes;
    my $r = Kelp::Routes->new( base => 'MyApp' );
    $r->add( '/home', 'home' );

=head1 DESCRIPTION

The router provides the connection between the HTTP requests and the web
application code. It tells the application I<"If you see a request coming to
*this* URI, send it to *that* subroutine for processing">. For example, if a
request comes to C</home>, then send it to C<sub home> in the current
namespace. The process of capturing URIs and sending them to their corresponding
code is called routing.

This router was specifically crafted as part of the C<Kelp> web framework. It
is, however, possible to use it on its own, if needed.

It provides a simple, yet sophisticated routing utilizing Perl 5.10's
regular expressions, which makes it fast, robust and reliable.

The routing process can roughly be broken down into three steps:

=over

=item B<Adding routes>

First you create a router object:

    my $r = Kelp::Routes->new();

Then you add your application's routes and their descriptions:

    $r->add( '/path' => 'Module::function' );
    ...

If you add a trailing slash to your route, it will be mandatory in request path
for the route to match. If you don't add it, it will be optional.

=item B<Matching>

Once you have your routes added, you can match with the L</match> subroutine.

    my $patterns_aref = $r->match( $path, $method );

The Kelp framework already does matching for you, so you may never
have to do your own matching. The above example is provided only for
reference.

The order of patterns in C<$patterns_aref> is the order in which the framework
will be executing the routes. Bridges are always before regular routes, and
shorter routes come first within a given type (bridge or no-bridge). If route
patterns are exactly the same, the ones defined earlier will also be executed
earlier.

Routes will continue going through that execution chain until one of the
bridges return a false value, one of the non-bridges return a defined value, or
one of the routes renders something explicitly using methods in
L<Kelp::Response>. It is generally not recommended to have more than one
non-bridge route matching a pattern as it may be harder to debug which one gets
to actually render a response.

=item B<Building URLs from routes>

You can name each of your routes, and use that name later to build a URL:

    $r->add( '/begin' => { to => 'function', name => 'home' } );
    my $url = $r->url('home');    # /begin

This can be used in views and other places where you need the full URL of
a route.

=back

=head1 PLACEHOLDERS

Often routes may get more complicated. They may contain variable parts. For
example this one C</user/1000> is expected to do something with user ID 1000.
So, in this case we need to capture a route that begins with C</user/> and then
has something else after it.

Naturally, when it comes to capturing routes, the first instinct of the Perl
programmer is to use regular expressions, like this:

    qr{/user/(\d+)} -> "sub home"

This module will let you do that, however regular expressions can get very
complicated, and it won't be long before you lose track of what does what.

This is why a good router (this one included) allows for I<named placeholders>.
These are words prefixed with special symbols, which denote a variable piece in
the URI. To use the above example:

    "/user/:id" -> "sub home"

It looks a little cleaner.

Placeholders are variables you place in the route path. They are identified by
a prefix character and their names must abide to the rules of a regular Perl
variable. If necessary, curly braces can be used to separate placeholders from
the rest of the path.

There are three types of place holders:

=head2 Explicit

These placeholders begin with a column (C<:>) and must have a value in order for the
route to match. All characters are matched, except for the forward slash.

    $r->add( '/user/:id' => 'Module::sub' );
    # /user/a       -> match (id = 'a')
    # /user/123     -> match (id = 123)
    # /user/        -> no match
    # /user         -> no match
    # /user/10/foo  -> no match

    $r->add( '/page/:page/line/:line' => 'Module::sub' );
    # /page/1/line/2        -> match (page = 1, line = 2)
    # /page/bar/line/foo    -> match (page = 'bar', line = 'foo')
    # /page/line/4          -> no match
    # /page/5               -> no match

    $r->add( '/{:a}ing/{:b}ing' => 'Module::sub' );
    # /walking/singing      -> match (a = 'walk', b = 'sing')
    # /cooking/ing          -> no match
    # /ing/ing              -> no match

=head2 Optional

Optional placeholders begin with a question mark C<?> and denote an optional
value. You may also specify a default value for the optional placeholder via
the L</defaults> option. Again, like the explicit placeholders, the optional
ones capture all characters, except the forward slash.

    $r->add( '/data/?id' => 'Module::sub' );
    # /bar/foo          -> match ( id = 'foo' )
    # /bar/             -> match ( id = undef )
    # /bar              -> match ( id = undef )

    $r->add( '/:a/?b/:c' => 'Module::sub' );
    # /bar/foo/baz      -> match ( a = 'bar', b = 'foo', c = 'baz' )
    # /bar/foo          -> match ( a = 'bar', b = undef, c = 'foo' )
    # /bar              -> no match
    # /bar/foo/baz/moo  -> no match

Optional default values may be specified via the C<defaults> option.

    $r->add(
        '/user/?name' => {
            to       => 'Module::sub',
            defaults => { name => 'hank' }
        }
    );

    # /user             -> match ( name = 'hank' )
    # /user/            -> match ( name = 'hank' )
    # /user/jane        -> match ( name = 'jane' )
    # /user/jane/cho    -> no match

=head2 Wildcards

The wildcard placeholders expect a value and capture all characters, including
the forward slash.

    $r->add( '/:a/*b/:c'  => 'Module::sub' );
    # /bar/foo/baz/bat  -> match ( a = 'bar', b = 'foo/baz', c = 'bat' )
    # /bar/bat          -> no match

=head2 Slurpy

Slurpy placeholders will take as much as they can or nothing. It's a mix of a
wildcard and optional placeholder.

    $r->add( '/path/>rest'  => 'Module::sub' );
    # /path            -> match ( rest = undef )
    # /path/foo        -> match ( rest = '/foo' )
    # /path/foo/bar    -> match ( rest = '/foo/bar' )

Just like optional parameters, they may have C<defaults>.

=head2 Using curly braces

Curly braces may be used to separate the placeholders from the rest of the
path:

    $r->add( '/{:a}ing/{:b}ing' => 'Module::sub' );
    # /looking/seeing       -> match ( a = 'look', b = 'see' )
    # /ing/ing              -> no match

    $r->add( '/:a/{?b}ing' => 'Module::sub' );
    # /bar/hopping          -> match ( a = 'bar', b = 'hopp' )
    # /bar/ing              -> match ( a = 'bar' )
    # /bar                  -> no match

    $r->add( '/:a/{*b}ing/:c' => 'Module::sub' );
    # /bar/hop/ping/foo     -> match ( a = 'bar', b = 'hop/p', c = 'foo' )
    # /bar/ing/foo          -> no match

=head1 BRIDGES

The L</match> subroutine will stop and return the route that best matches the
specified path. If that route is marked as a bridge, then L</match> will
continue looking for another match, and will eventually return an array of one or
more routes. Bridges can be used for authentication or other route preprocessing.

    $r->add( '/users/*', { to => 'Users::auth', bridge => 1 } );
    $r->add( '/users/:action' => 'Users::dispatch' );

The above example will require F</users/profile> to go through two
subroutines: C<Users::auth> and C<Users::dispatch>:

    my $arr = $r->match('/users/view');
    # $arr is an array of two routes now, the bridge and the last one matched

Just like regular routes, bridges can render a response, but it must be done
manually by calling C<< $self->res->render() >> or other methods from
L<Kelp::Response>. When a render happens in a bridge, its return value will be
discarded and no other routes in chain will be run as if a false value was
returned. For example, this property can be used to render a login page in
place instead of a 403 response, or just simply redirect to one.

=head1 TREES

A quick way to add bridges is to use the L</tree> option. It allows you to
define all routes under a bridge. Example:

    $r->add(
        '/users/*' => {
            to   => 'users#auth',
            name => 'users',
            tree => [
                '/profile' => {
                    name => 'profile',
                    to   => 'users#profile'
                },
                '/settings' => {
                    name => 'settings',
                    to   => 'users#settings',
                    tree => [
                        '/email' => { name => 'email', to => 'users#email' },
                        '/login' => { name => 'login', to => 'users#login' }
                    ]
                }
            ]
        }
    );

The above call to C<add> causes the following to occur under the hood:

=over

=item

The paths of all routes inside the tree are joined to the path of their
parent, so the following five new routes are created:

    /users                  -> MyApp::Users::auth
    /users/profile          -> MyApp::Users::profile
    /users/settings         -> MyApp::Users::settings
    /users/settings/email   -> MyApp::Users::email
    /users/settings/login   -> MyApp::Users::login

=item

The names of the routes are joined via C<_> with the name of their parent:

    /users                  -> 'users'
    /users/profile          -> 'users_profile'
    /users/settings         -> 'users_settings'
    /users/settings/email   -> 'users_settings_email'
    /users/settings/login   -> 'users_settings_login'

=item

The C</users> and C</users/settings> routes are automatically marked as
bridges, because they contain a tree.

=back

=head1 LOCATIONS

Instead of using trees, you can alternatively use locations returned by the
L</add> method, which will work exactly the same. The object returned from
C<add> will be a facade implementing a localized version of C<add>:

    # /users
    my $users = $r->add( '/users' => {
        to   => 'users#auth',
        name => 'users',
    } );

    # /users/profile, /users becomes a bridge
    my $profile = $users->add( '/profile' => {
        name => 'profile',
        to   => 'users#profile'
    } );

    # /users/settings, has its own tree so it's a bridge
    my $settings = $users->add( '/settings' => {
        name => 'settings',
        to   => 'users#settings',
        tree => [
            '/email' => { name => 'email', to => 'users#email' },
            '/login' => { name => 'login', to => 'users#login' }
        ],
    } );

=head1 PLACK APPS

Kelp makes it easy to nest Plack/PSGI applications inside your Kelp app. All
you have to do is provide a Plack application runner in C<to> and set C<psgi>
to a true value.

    use Plack::App::File;

    $r->add( '/static/>path' => {
        to => Plack::App::File->new(root => "/path/to/static")->to_app,
        psgi => 1,
    });

You must provide a proper placeholder at the end if you want your app to occpy
all the subpaths under the base path. A slurpy placeholder like C<< >path >>
works best and mimics L<Plack::App::URLMap>'s behavior. B<It is an error to
only provide a placeholder in the middle of the pattern>. Kelp will take B<the
last placeholder> and assume it comes B<after> the base route. If it doesn't,
the paths set for the nested app will be wrong.

Note that a route cannot have C<psgi> and C<bridge> (or C<tree>) simultaneously.

=head1 PLACK MIDDLEWARES

If your route is not a Plack app and you want to reuse Plack middleware when
handling it, you may use C<psgi_middleware> and wrap L<Kelp/NEXT_APP>:

    use Plack::Middleware::ContentMD5;

    $r->add('/checksummed' => {
        to => 'get_content',
        psgi_middleware => Plack::Middleware::ContentMD5->wrap(Kelp->NEXT_APP),
    });

You can also apply C<psgi_middleware> to bridges. Also, it is more readable to
use L<Plack::Builder> for this:

    use Plack::Builder;

    $r->add('/api' => {
        to => sub { 1 }, # always pass through
        bridge => 1,
        psgi_middleware => builder {
            enable 'Auth::Basic', authenticator => sub { ... };
            Kelp->NEXT_APP;
        },
    });

Now everything under C</api> will go through this middleware. Note however that
C<psgi_middleware> is app-level middleware, not route-level. This means that
even if your bridge was to cut off traffic (return false value), all middleware
declared in routes will still have to run regardless, and it will run even
before the first route is executed. Don't think about it as I<"middleware for a
route">, but rather as I<"middleware for an app which is going to execute that
route">.

It is worth noting that using middleware in your routes will result in better
performance than global middleware. Having a ton of global middleware, even if
bound to a specific route, may result in quite a big overhead since it will
have to do a bunch of regular expression matches or string comparisons for
every route in your system. On the other hand, Kelp router is pretty optimized
and will only do the matching once, and only the matched routes will have to go
through this middleware.

=head1 ATTRIBUTES

=head2 base

Sets the base class for the routes destinations.

    my $r = Kelp::Routes->new( base => 'MyApp' );

This will prepend C<MyApp::> to all route destinations.

    $r->add( '/home' => 'home' );          # /home -> MyApp::home
    $r->add( '/user' => 'user#home' );     # /user -> MyApp::User::home
    $r->add( '/view' => 'User::view' );    # /view -> MyApp::User::view

A Kelp application will automatically set this value to the name of the main
class. If you need to use a route located in another package, you must prefix
it with a plus sign:

    # Problem:

    $r->add( '/outside' => 'Outside::Module::route' );
    # /outside -> MyApp::Outside::Module::route
    # (most likely not what you want)

    # Solution:

    $r->add( '/outside' => '+Outside::Module::route' );
    # /outside -> Outside::Module::route

=head2 rebless

Switch used to set whether the router should rebless the app into the
controller classes (subclasses of L</base>). Boolean value, false by default.

=head2 pattern_obj

A full class name of an object used for each pattern, L<Kelp::Routes::Pattern>
by default. Works the same as its counterpart L<Kelp/request_obj>.

=head2 fatal

A boolean. If set to true, errors in route definitions will crash the
application instead of just raising a warning. False by default.

=head2 cache

Routes will be cached in memory, so repeating requests will be dispatched much
faster. The default cache entries never expire, so it will continue to grow as
long as the process lives. It also stores full L<Kelp::Routes::Pattern>
objects, which is fast and light when stored in Perl but makes it cumbersome
when they are serialized.

The C<cache> attribute can optionally be initialized with an instance of a
caching module with interface similar to L<CHI> and L<Cache>. This allows for
giving them expiration time and possibly sharing them between processes, but
extra care must be taken to properly serialize them. Patterns are sure to
contain hardly serializable code references and are way heavier when
serialized. The cache should probably be configured to have an in-memory L1
cache which will map a serialized route identifier (stored in the main cache)
to a pattern object registered in the router. The module interface should at
the very least provide the following methods:

=head3 get($key)

retrieve a key from the cache

=head3 set($key, $value, $expiration)

set a key in the cache

=head3 clear()

clear all cache

The caching module should be initialized in the config file:

    # config.pl
    {
        modules_init => {
            Routes => {
                cache => Cache::Memory->new(
                    namespace       => 'MyApp',
                    default_expires => '3600 sec'
                );
            }
        }
    }

=head1 SUBROUTINES

=head2 add

Adds a new route definition to the routes array.

    $r->add( $path, $destination );

C<$path> can be a path string, e.g. C<'/user/view'> or an ARRAY containing a
method and a path, e.g. C<[ PUT =E<gt> '/item' ]>.

Returns an object on which you can call C<add> again. If you do, the original
route will become a bridge. It will work as if you included the extra routes in
the route's C<tree>.

The route destination is very flexible. It can be one of these three things:

=over

=item

A string name of a subroutine, for example C<"Users::item">. Using a C<#> sign
to replace C<::> is also allowed, in which case the name will get converted.
C<"users#item"> becomes C<"Users::item">.

    $r->add( '/home' => 'user#home' );

=item

A code reference.

    $r->add( '/system' => sub { return \%ENV } );

=item

A hashref with options.

    # GET /item/100 -> MyApp::Items::view
    $r->add(
        '/item/:id', {
            to     => 'items#view',
            method => 'GET'
        }
    );

See L</Destination Options> for details.

=back

=head3 Destination Options

There are a number of options you can add to modify the behavior of the route,
if you specify a hashref for a destination:

=head4 to

Sets the destination for the route. It should be a subroutine name or CODE
reference.

    $r->add( '/home' => { to => 'users#home' } ); # /home -> MyApp::Users::home
    $r->add( '/sys' => { to => sub { ... } });    # /sys -> execute code
    $r->add( '/item' => { to => 'Items::handle' } ) ;   # /item -> MyApp::Items::handle
    $r->add( '/item' => { to => 'items#handle' } );    # Same as above

=head4 method

Specifies an HTTP method to be considered by L</match> when matching a route.

    # POST /item -> MyApp::Items::add
    $r->add(
        '/item' => {
            method => 'POST',
            to     => 'items#add'
        }
    );

A shortcut for the above is this:

    $r->add( [ POST => '/item' ] => 'items#add' );

=head4 name

Give the route a name, and you can always use it to build a URL later via the L</url>
subroutine.

    $r->add(
        '/item/:id/:name' => {
            to   => 'items#view',
            name => 'item'
        }
    );

    # Later
    $r->url( 'item', id => 8, name => 'foo' );    # /item/8/foo

=head4 check

A hashref of checks to perform on the captures. It should contain capture
names and stringified regular expressions. Do not use C<^> and C<$> to denote
beginning and ending of the matched expression, because it will get embedded
in a bigger Regexp.

    $r->add(
        '/item/:id/:name' => {
            to    => 'items#view',
            check => {
                id   => '\d+',          # id must be a digit
                name => 'open|close'    # name can be 'open' or 'close'
            }
          }
    );

=head4 defaults

Set default values for optional placeholders.

    $r->add(
        '/pages/?id' => {
            to       => 'pages#view',
            defaults => { id => 2 }
        }
    );

    # /pages    -> match ( id = 2 )
    # /pages/   -> match ( id = 2 )
    # /pages/4  -> match ( id = 4 )

=head4 bridge

If set to 1 this route will be treated as a bridge. Please see L</BRIDGES>
for more information.

=head4 tree

Creates a tree of sub-routes. See L</TREES> for more information and examples.

=head2 url

    my $url = $r->url($path, @arguments);

Builds an url from path and arguments. If the request is named a name can be specified instead.

=head2 match

Returns an array of L<Kelp::Routes::Pattern> objects that match the path
and HTTP method provided. Each object will contain a hash with the named
placeholders in L<Kelp::Routes::Pattern/named>, and an array with their
values in the order they were specified in the pattern in
L<Kelp::Routes::Pattern/param>.

    $r->add( '/:id/:name', "route" );
    for my $pattern ( @{ $r->match('/15/alex') } ) {
        $pattern->named;    # { id => 15, name => 'alex' }
        $pattern->param;    # [ 15, 'alex' ]
    }

Routes that used regular expressions instead of patterns will only initialize
the C<param> array with the regex captures, unless those patterns are using
named captures in which case the C<named> hash will also be initialized.

=head2 dispatch

    my $result = $r->dispatch($kelp, $route_pattern);

Dispatches an instance of L<Kelp::Routes::Pattern> by running the route
destination specified in L<Kelp::Routes::Pattern/dest>. If dest is not set, it
will be computed using L</load_destination> with unformatted
L<Kelp::Routes::Pattern/to>.

The C<$kelp> instance may be shallow-cloned and reblessed into another class if
it is a subclass of L</base> and L</rebless> is configured. Modifications made
to top-level attributes of C<$kelp> object will be gone after the action is
complete.

=head2 build_pattern

Override this method to do change the creation of the pattern. Same role as L<Kelp/build_request>.

=head2 format_to

Override this method to change the formatting process of L<Kelp::Routes::Pattern/to>. See code for details.

=head2 load_destination

Override this method to change the loading process of L<Kelp::Routes::Pattern/dest>. See code for details.

=head2 wrap_psgi

Override this method to change the way a Plack/PSGI application is extracted from a destination. See code for details.

=head1 EXTENDING

This is the default router class for each new Kelp application, but it doesn't
have to be. You can create your own subclass that better suits your needs. It's
generally enough to override the L</dispatch>, L</format_to> or
L</load_destination> methods.

=head1 ACKNOWLEDGEMENTS

This module was inspired by L<Routes::Tiny>.

=cut

