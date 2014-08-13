package Kelp::Routes;

use Carp;

use Kelp::Base;
use Kelp::Routes::Pattern;
use Plack::Util;
use Class::Inspector;

attr base    => '';
attr routes  => sub { [] };
attr names   => sub { {} };

# Cache
attr _CACHE => sub { {} };
attr cache => sub {
    my $self = shift;
    Plack::Util::inline_object(
        get   => sub { $self->_CACHE->{ $_[0] } },
        set   => sub { $self->_CACHE->{ $_[0] } = $_[1] },
        clear => sub { $self->_CACHE( {} ) }
    );
};

sub add {
    my ( $self, $pattern, $descr ) = @_;
    $self->_parse_route( {}, $pattern, $descr );
}

sub clear {
    $_[0]->routes( [] );
    $_[0]->cache->clear;
    $_[0]->names( {} );
}

sub _camelize {
    my ( $string, $base ) = @_;
    return $string unless $string;
    my @parts = split( /\#/, $string );
    my $sub = pop @parts;
    @parts = map {
        join '', map { ucfirst lc } split /\_/
    } @parts;
    unshift @parts, $base if $base;
    return join( '::', @parts, $sub );
}

sub _parse_route {
    my ( $self, $parent, $key, $val ) = @_;

    # Scalar, e.g. path => 'bar#foo'
    # CODE, e.g. path => sub { ... }
    if ( !ref($val) || ref($val) eq 'CODE' ) {
        $val = { to => $val };
    }

    # Sanity check
    if ( ref($val) ne 'HASH' ) {
        carp "Route description must be a SCALAR, CODE or HASH. Skipping.";
        return;
    }

    # 'to' is required
    if ( !exists $val->{to} ) {
        carp "Route is missing destination. Skipping.";
        return;
    }

    # Format destination
    if ( !ref $val->{to} ) {
        my $sigil = $val->{to} =~ s/^(\+)// ? $1 : undef;
        $val->{to} = _camelize( $val->{to}, $sigil ? undef : $self->base );

        # Load the class, if there is one and it is not 'main'
        if (   defined $val->{to}
            && $val->{to} =~ /^(.+)::(\w+)$/
            && $1 ne 'main'
            && !Class::Inspector->loaded($1) ) {
            Plack::Util::load_class($1);
        }
    }

    # Handle the value part
    if ( ref($key) eq 'ARRAY' ) {
        my ( $method, $pattern ) = @$key;
        if ( !grep { $method eq $_ } qw/GET POST PUT DELETE/ ) {
            carp "Using an odd method: $method";
        }
        $val->{method} = $method;
        $key = $pattern;
    }

    # Only SCALAR and Regexp allowed
    if ( ref($key) && ref($key) ne 'Regexp' ) {
        carp "Pattern $key can not be computed.";
        return;
    }

    $val->{pattern} = $key;

    my $tree;
    if ( $tree = delete $val->{tree} ) {
        if ( ref($tree) ne 'ARRAY' ) {
            carp "Tree must be an ARRAY. Skipping.";
            $tree = undef;
        }
        else {
            $val->{bridge} = 1;
        }
    }
    $tree //= [];

    # Parrent defined?
    if (%$parent) {
        if ( $val->{name} && $parent->{name} ) {
            $val->{name} = $parent->{name} . '_' . $val->{name};
        }
        $val->{pattern} = $parent->{pattern} . $val->{pattern};
    }

    # Create pattern object
    push @{ $self->routes }, Kelp::Routes::Pattern->new(%$val);

    # Add route index to names
    if ( my $name = $val->{name} ) {
        if ( exists $self->names->{$name} ) {
            carp "Redefining route name $name";
        }
        $self->names->{$name} = scalar( @{ $self->routes } ) - 1;
    }

    while (@$tree) {
        my ( $k, $v ) = splice( @$tree, 0, 2 );
        $self->_parse_route( $val, $k, $v );
    }
}

sub url {
    my $self = shift;
    my $name = shift // die "Route name is missing";
    my %args = @_ == 1 ? %{ $_[0] } : @_;

    return $name unless exists $self->names->{$name};
    my $route = $self->routes->[ $self->names->{$name} ];
    return $route->build(%args);
}

sub match {
    my ( $self, $path, $method ) = @_;

    # Look for this path and method in the cache. If found,
    # return the array of routes that matched the previous time.
    # If not found, then return all routes.
    my $key = $path . ':' . ( $method // '' );
    my $routes = $self->cache->get($key) // $self->routes;

    # Look through all routes, grep the ones that match
    # and sort them by 'bridge' and 'pattern'
    my @processed =
      sort { $b->bridge <=> $a->bridge || $a->pattern cmp $b->pattern }
      grep { $_->match( $path, $method ) } @$routes;

    my $value = \@processed;
    $self->cache->set( $key, $value );
    return $value;
}

sub dispatch {
    my ( $self, $app, $route ) = @_;
    $app   || die "Application instance required";
    $route || die "No route pattern instance supplied";

    # Shortcuts
    my $req = $app->req;
    my $to  = $route->to;

    # Destination must be either a scalar, or a code reference
    if ( !$to || ref $to && ref $to ne 'CODE' ) {
        die 'Invalid destination for ' . $req->path;
    }

    # If the destination is not a code reference, then we assume it's
    # a fully qualified function name, so we find its reference
    unless ( ref $to ) {

        # Check if the destination function exists
        unless ( exists &$to ) {
            die sprintf( 'Route not found %s for %s', $to, $req->path );
        }

        # Move to reference
        $to = \&{$to};
    }

    return $to->( $app, @{ $route->param } );
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

=cut

=item B<Matching>

Once you have your routes added, you can match with the L</match> subroutine.

    $r->match( $path, $method );

The Kelp framework already does matching for you, so you may never
have to do your own matching. The above example is provided only for
reference.

=cut

=item B<Building URLs from routes>

You can name each of your routes, and use that name later to build a URL:

    $r->add( '/begin' => { to => 'function', name => 'home' } );
    my $url = $r->url('home');    # /begin

This can be used in views and other places where you need the full URL of
a route.

=cut

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

    $r->add( '/users', { to => 'Users::auth', bridge => 1 } );
    $r->add( '/users/:action' => 'Users::dispatch' );

The above example will require F</users/profile> to go through two
subroutines: C<Users::auth> and C<Users::dispatch>:

    my $arr = $r->match('/users/view');
    # $arr is an array of two routes now, the bridge and the last one matched

=head1 TREES

A quick way to add bridges is to use the L</tree> option. It allows you to
define all routes under a bridge. Example:

    $r->add(
        '/users' => {
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

=cut

=item

The names of the routes are joined via C<_> with the name of their parent:

    /users                  -> 'users'
    /users/profile          -> 'users_profile'
    /users/settings         -> 'users_settings'
    /users/settings/email   -> 'users_settings_email'
    /users/settings/login   -> 'users_settings_login'

=cut

=item

The C</users> and C</users/settings> routes are automatically marked as
bridges, because they contain a tree.

=cut

=back

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

=head2 cache

Routes will be cached in memory, so repeating requests will be dispatched much
faster. The C<cache> attribute can optionally be initialized with an instance of
a caching module with interface similar to L<CHI> and L<Cache>.
The module interface should at the very least provide the following methods:

=head3 get($key) - retrieve a key from the cache

=head3 set($key, $value, $expiration) - set a key in the cache

=head3 clear() - clear all cache

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

The route destination is very flexible. It can be one of these three things:

=over

=item

A string name of a subroutine, for example C<"Users::item">. Using a C<#> sign
to replace C<::> is also allowed, in which case the name will get converted.
C<"users#item"> becomes C<"Users::item">.

    $r->add( '/home' => 'user#home' );

=cut

=item

A code reference.

    $r->add( '/system' => sub { return \%ENV } );

=cut

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

=cut

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

If set to one this route will be treated as a bridge. Please see L</bridges>
for more information.

=head4 tree

Creates a tree of sub-routes. See L</trees> for more information and examples.

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

=head1 EXTENDING

This is the default router class for each new Kelp application, but it doesn't
have to be. You can create your own subclass that better suits your needs. It's
generally enough to override the L</dispatch> method.

Kelp comes with L<Kelp::Routes::Controller>, a router extension which reblesses
the application instance into a controller class.

=head1 ACKNOWLEDGEMENTS

This module was inspired by L<Routes::Tiny>.

=cut
