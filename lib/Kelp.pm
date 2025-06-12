package Kelp;

use Kelp::Base;

use Carp qw/ longmess croak /;
use FindBin;
use Try::Tiny;
use Sys::Hostname;
use Plack::Util;
use Class::Inspector;
use List::Util qw(any);
use Scalar::Util qw(blessed);

our $VERSION = '2.22';

# Basic attributes
attr -host => hostname;
attr mode => $ENV{KELP_ENV} // $ENV{PLACK_ENV} // 'development';
attr -path => $FindBin::Bin;
attr -name => sub { (ref($_[0]) =~ /(\w+)$/) ? $1 : 'Noname' };
attr request_obj => 'Kelp::Request';
attr response_obj => 'Kelp::Response';
attr context_obj => 'Kelp::Context';
attr middleware_obj => 'Kelp::Middleware';

# Debug
attr long_error => $ENV{KELP_LONG_ERROR} // 0;

# The charset is set to UTF-8 by default in config module.
# No default here because we want to support 'undef' charset
attr charset => sub { $_[0]->config('charset') };
attr request_charset => sub { $_[0]->config('request_charset') };

# Name the config module
attr config_module => 'Config';

# Undocumented.
# Used to unlock the undocumented features of the Config module.
attr __config => undef;

attr -loaded_modules => sub { {} };

# Current context of the application - tracks the state application is in,
# especially when it comes to managing controller instances.
attr context => \&build_context;

# registered application encoder modules
attr encoder_modules => sub { {} };

# Initialization
sub new
{
    my $self = shift->SUPER::new(@_);

    Kelp::Util::_DEBUG(1 => 'Loading essential modules...');

    # Always load these modules, but allow client to override
    $self->_load_config();
    $self->_load_routes();

    Kelp::Util::_DEBUG(1 => 'Loading modules from config...');

    # Load the modules from the config
    if (defined(my $modules = $self->config('modules'))) {
        $self->load_module($_) for (@$modules);
    }

    Kelp::Util::_DEBUG(1 => 'Calling build method...');

    $self->build();
    return $self;
}

sub new_anon
{
    state $last_anon = 0;
    my $class = shift;

    # make sure we don't eval something dodgy
    die "invalid class for new_anon"
        if ref $class    # not a string
        || !$class    # not an empty string, undef or 0
        || !Class::Inspector->loaded($class)    # not a loaded class
        || !$class->isa(__PACKAGE__)    # not a correct class
        ;

    my $anon_class = "Kelp::Anonymous::$class" . ++$last_anon;
    my $err = do {
        local $@;
        my $eval_status = eval qq[
            {
                package $anon_class;
                use parent -norequire, '$class';

                sub _real_class { '$class' }
            }
            1;
        ];
        $@ || !$eval_status;
    };

    if ($err) {
        die "Couldn't create anonymous Kelp instance: " .
            (length $err > 1 ? $err : 'unknown error');
    }

    return $anon_class->new(@_);
}

sub _load_config
{
    my $self = shift;
    $self->load_module($self->config_module, extra => $self->__config);

    Kelp::Util::_DEBUG(config => 'Merged configuration: ', $self->config_hash);
}

sub _load_routes
{
    my $self = shift;
    $self->load_module('Routes');
}

# Create a shallow copy of the app, optionally blessed into a
# different subclass.
sub _clone
{
    my $self = shift;
    my $subclass = shift || ref($self);

    ref $self or croak '_clone requires instance';
    return bless {%$self}, $subclass;
}

sub load_module
{
    my ($self, $name, %args) = @_;

    # A module name with a leading + indicates it's already fully
    # qualified (i.e., it does not need the Kelp::Module:: prefix).
    my $prefix = $name =~ s/^\+// ? undef : 'Kelp::Module';

    # Make sure the module was not already loaded
    return if $self->loaded_modules->{$name};

    my $class = Plack::Util::load_class($name, $prefix);
    my $module = $self->loaded_modules->{$name} = $class->new(app => $self);

    # When loading the Config module itself, we don't have
    # access to $self->config yet. This is why we check if
    # config is available, and if it is, then we pull the
    # initialization hash.
    my $args_from_config = {};
    if ($self->can('config')) {
        $args_from_config = $self->config("modules_init.$name") // {};
    }

    Kelp::Util::_DEBUG(modules => "Loading $class module with args: ", {%$args_from_config, %args});

    $module->build(%$args_from_config, %args);
    return $module;
}

# Override this one to add custom initializations
sub build
{
}

# Override to use a custom context object
sub build_context
{
    return Kelp::Util::load_package($_[0]->context_obj)->new(
        app => $_[0],
    );
}

# Override to use a custom request object
sub build_request
{
    return Kelp::Util::load_package($_[0]->request_obj)->new(
        app => $_[0],
        env => $_[1],
    );
}

sub req
{
    my $self = shift;
    return $self->context->req(@_);
}

# Override to use a custom response object
sub build_response
{
    return Kelp::Util::load_package($_[0]->response_obj)->new(
        app => $_[0],
    );
}

sub res
{
    my $self = shift;
    return $self->context->res(@_);
}

# Override to change what happens before the route is handled
sub before_dispatch
{
    my ($self, $destination) = @_;

    # Log info about the route
    if ($self->can('logger')) {
        my $req = $self->req;

        $self->info(
            sprintf "%s: %s - %s %s - %s",
            ref $self,
            $req->address, $req->method,
            $req->path, $destination
        );
    }
}

# Override to change what happens when nothing gets rendered
sub after_unrendered
{
    my ($self, $match) = @_;

    # render 404 if only briges matched
    if ($match->[-1]->bridge) {
        $self->res->render_404;
    }

    # or die with error
    else {
        die $match->[-1]->to
            . " did not render for method "
            . $self->req->method;
    }
}

# Override to manipulate the end response
sub before_finalize
{
    my $self = shift;
    $self->res->header('X-Framework' => 'Perl Kelp');
}

# Override this to wrap more middleware around the app
sub run
{
    my $self = shift;
    my $app = sub { $self->psgi(@_) };

    Kelp::Util::_DEBUG(1 => 'Running the application...');

    my $middleware = Kelp::Util::load_package($self->middleware_obj)->new(
        app => $self,
    );

    return $middleware->wrap($app);
}

sub _psgi_internal
{
    my ($self, $match) = @_;
    my $req = $self->req;
    my $res = $self->res;

    # Go over the entire route chain
    for my $route (@$match) {

        # Dispatch
        $req->named($route->named);
        $req->route_name($route->name);
        my $data = $self->routes->dispatch($self, $route);

        if ($route->bridge) {

            # Is it a bridge? Bridges must return a true value to allow the
            # rest of the routes to run. They may also have rendered
            # something, in which case trust that and don't render 403 (but
            # still end the execution chain)

            if (!$data) {
                $res->render_403 unless $res->rendered;
            }
        }
        elsif (defined $data) {

            # If the non-bridge route returned something, then analyze it and render it

            # Handle delayed response if CODE
            return $data if ref $data eq 'CODE';
            $res->render($data) unless $res->rendered;
        }

        # Do not go any further if we got a render
        last if $res->rendered;
    }

    # If nothing got rendered
    if (!$res->rendered) {
        $self->context->run_method(after_unrendered => ($match));
    }

    return $self->finalize;
}

sub NEXT_APP
{
    return sub {
        (shift @{$_[0]->{'kelp.execution_chain'}})->($_[0]);
    };
}

sub psgi
{
    my ($self, $env) = @_;

    # Initialize the app object state
    $self->context->clear;
    my $req = $self->req($self->build_request($env));
    my $res = $self->res($self->build_response);

    # Get route matches
    my $match = $self->routes->match($req->path, $req->method);

    # None found? Short-circuit and show 404
    if (!@$match) {
        $res->render_404;
        return $self->finalize;
    }

    return try {
        $env->{'kelp.execution_chain'} = [
            (grep { defined } map { $_->psgi_middleware } @$match),
            sub { $self->_psgi_internal($match) },
        ];

        return Kelp->NEXT_APP->($env);
    }
    catch {
        my $exception = $_;

        # CONTEXT CHANGE: we need to clear response state because anything that
        # was rendered beforehand is no longer valid. Body and code will be
        # replaced automatically with render methods, but headers must be
        # cleared explicitly
        $res->headers->clear;

        if (blessed $exception && $exception->isa('Kelp::Exception')) {

            # only log it as an error if the body is present
            $self->logger('error', $exception->body)
                if $self->can('logger') && defined $exception->body;

            $res->render_exception($exception);
        }
        else {
            my $message = $self->long_error ? longmess($exception) : $exception;

            # Log error
            $self->logger('critical', $message) if $self->can('logger');

            # Render an application erorr (hides details on production)
            $res->render_500($exception);
        }

        return $self->finalize;
    };
}

sub finalize
{
    my $self = shift;

    # call it with current context, so that it will get controller's hook if
    # possible
    $self->context->run_method(before_finalize => ());

    return $self->res->finalize;
}

#----------------------------------------------------------------
# Request and Response shortcuts
#----------------------------------------------------------------
sub param
{
    my $self = shift;
    unshift @_, $self->req;

    # goto will allow carp show the correct caller
    goto $_[0]->can('param');
}

sub session { shift->req->session(@_) }

sub stash
{
    my $self = shift;
    @_ ? $self->req->stash->{$_[0]} : $self->req->stash;
}

sub named
{
    my $self = shift;
    @_ ? $self->req->named->{$_[0]} : $self->req->named;
}

#----------------------------------------------------------------
# Utility
#----------------------------------------------------------------

sub is_production
{
    my $self = shift;
    return any { lc $self->mode eq $_ } qw(deployment production);
}

sub url_for
{
    my ($self, $name, @args) = @_;
    my $result = $name;
    try { $result = $self->routes->url($name, @args) };
    return $result;
}

sub abs_url
{
    my ($self, $name, @args) = @_;
    my $url = $self->url_for($name, @args);
    return URI->new_abs($url, $self->config('app_url'))->as_string;
}

sub get_encoder
{
    my ($self, $type, $name) = @_;

    my $encoder = $self->encoder_modules->{$type} //
        croak "No $type encoder";

    return $encoder->get_encoder($name);
}

1;

__END__

=pod

=head1 NAME

Kelp - A web framework light, yet rich in nutrients.

=head1 SYNOPSIS

    package MyApp;
    use parent 'Kelp';

    # bootstrap your application
    sub build {
        my ($self) = @_;

        my $r = $self->routes;

        $r->add('/simple/route', 'route_handler');
        $r->add('/route/:name', {
            to => 'namespace::controller::action',
            ... # other options, see Kelp::Routes
        });
    }

    # example route handler
    sub route_handler {
        my ($kelp_instance, @route_parameters) = @_;

        return 'text to be rendered';
    }

    1;

=head1 DESCRIPTION

Kelp is a light, modular web framework built on top of Plack.

This document lists all the methods and attributes available in the main
instance of a Kelp application, passed as a first argument to route handling
routines. If you're just getting started, you may be more interested in the
following documentation pages:

See L<Kelp::Manual> for a complete reference.

See L<Kelp::Manual::Cookbook> for solutions to common problems.

=head1 REASONS TO USE KELP

=over

=item

B<Plack ecosystem>. Kelp isn't just compatible with L<Plack>, it's built on top
of it. Your application can be supported by a collection of already available Plack
components.

=item

B<Advanced Routing>. Create intricate, yet simple ways to capture HTTP requests
and route them to their designated code. Use explicit and optional named
placeholders, wildcards, or just regular expressions.

=item

B<Flexible Configuration>. Use different configuration file for each
environment, e.g. development, deployment, etc. Merge a temporary configuration
into your current one for testing and debugging purposes.

=item

B<Enhanced Logging>. Log messages at different levels of emergency. Log to a
file, screen, or anything supported by L<Log::Dispatch>.

=item

B<Powerful Rendering>. Use the built-in auto-rendering logic, or the template
module of your choice to return rich text, html and JSON responses.

=item

B<JSON encoder/decoder>. Kelp can handle JSON-formatted requests and responses
automatically, making working with JSON much more enjoyable. On top of that, it
uses L<JSON::MaybeXS> to choose the best (fastest, most secure) backend
available.

=item

B<Extendable Core>. Kelp has straightforward code and uses pluggable modules
for everything. This allows anyone to extend it or add a module for a custom
interface. Writing Kelp modules is easy.

=item

B<Sleek Testing>. Kelp takes Plack::Test and wraps it in an object oriented
class of convenience methods. Testing is done via sending requests to your
routes, then analyzing the response.

=back

=head1 ATTRIBUTES

=head2 host

Gets the current hostname.

    sub some_route {
        my $self = shift;
        if ( $self->host eq 'prod-host' ) {
            ...
        }
    }

=head2 mode

Sets or gets the current mode. The mode is important for the app to know what
configuration file to merge into the main configuration. See
L<Kelp::Module::Config> for more information.

    my $app = MyApp->new( mode => 'development' );
    # conf/config.pl and conf/development.pl are merged with priority
    # given to the second one.

=head2 context_obj

Provide a custom package name to define the ::Context object. Defaults to
L<Kelp::Context>.

=head2 middleware_obj

Provide a custom package name to define the middleware object. Defaults to
L<Kelp::Middleware>.

=head2 request_obj

Provide a custom package name to define the ::Request object. Defaults to
L<Kelp::Request>.

=head2 response_obj

Provide a custom package name to define the ::Response object. Defaults to
L<Kelp::Response>.

=head2 config_module

Sets of gets the class of the configuration module to be loaded on startup. The
default value is C<Config>, which will cause the C<Kelp::Module::Config> to get
loaded. See the documentation for L<Kelp::Module::Config> for more information
and for an example of how to create and use other config modules.

=head2 loaded_modules

A hashref containing the names and instances of all loaded modules. For example,
if you have these two modules loaded: Template and JSON, then a dump of
the C<loaded_modules> hash will look like this:

    {
        Template => Kelp::Module::Template=HASH(0x208f6e8),
        JSON     => Kelp::Module::JSON=HASH(0x209d454)
    }

This can come in handy if your module does more than just registering a new method
into the application. Then, you can use its object instance to access that
additional functionality.


=head2 path

Gets the current path of the application. That would be the path to C<app.psgi>

=head2 name

Gets or sets the name of the application. If not set, the name of the main
class will be used.

    my $app = MyApp->new( name => 'Twittar' );

=head2 charset

Gets or sets the output encoding charset of the app. It will be C<UTF-8>, if
not set to anything else. The charset can also changed in the config files.

If the charset is explicitly configured to be C<undef> or false, the
application won't do any automatic encoding of responses, unless you set it by
explicitly calling L<Kelp::Response/charset>.

=head2 request_charset

Same as L</charset>, but only applies to the input. Request data will be
decoded using this charset or charset which came with the request.

If the request charset is explicitly configured to be C<undef> or false, the
application won't do any automatic decoding of requests, B<even if message came
with a charset>.

For details, see L<Kelp::Request/ENCODING>.

=head2 long_error

When a route dies, Kelp will by default display a short error message. Set this
attribute to a true value if you need to see a full stack trace of the error.
The C<KELP_LONG_ERROR> environment variable can also set this attribute.

=head2 req

This attribute only makes sense if called within a route definition. It will
contain a reference to the current L<Kelp::Request> instance.

    sub some_route {
        my $self = shift;
        if ( $self->req->is_json ) {
            ...
        }
    }

This attribute is a proxy to the same attribute in L</context>.

=head2 res

This attribute only makes sense if called within a route definition. It will
contain a reference to the current L<Kelp::Response> instance.

    sub some_route {
        my $self = shift;
        $self->res->json->render( { success => 1 } );
    }

This attribute is a proxy to the same attribute in L</context>.

=head2 context

This holds application's context. Its usage is advanced and only useful for
controller logic, but may allow for some introspection into Kelp.

For example, if you have a route in a controller and need to get the original
Kelp app object, you may call this:

    sub some_route {
        my $controller = shift;
        my $app = $controller->context->app;
    }

=head2 encoder_modules

A hash reference of registered encoder modules. Should only be interacted with
through L</get_encoder> or inside encoder module's code.

=head1 METHODS

=head2 new

    my $the_only_kelp = KelpApp->new;

A standard constructor. B<Cannot> be called multiple times: see L</new_anon>.

=head2 new_anon

    my $kelp1 = KelpApp->new_anon(config => 'conf1');
    my $kelp2 = KelpApp->new_anon(config => 'conf2');

B<Deprecated>. This only solves the problem in a basic scenario and has a
critical bug when it comes to subclassing and reblessing the app. The
C<new_anon> constructor itself will not be removed, but its internals will be
modified to use a more robust implementation method. It is not guaranteed to
work exactly the same for your use case with the new method. It's usually
better to treat every Kelp app like a singleton since that's how it was
designed.

A constructor that can be called repeatedly. Cannot be mixed with L</new>.

It works by creating a new anonymous class extending the class of your
application and running I<new> on it. C<ref $kelp> will return I<something
else> than the name of your Kelp class, but C<< $kelp->isa('KelpApp') >> will
be true. This will likely be useful during testing or when running multiple
instances of the same application with different configurations.

=head2 build

On its own, the C<build> method doesn't do anything. It is called by the
constructor, so it can be overridden to add route destinations and
initializations.

    package MyApp;

    sub build {
        my $self = shift;
        my $r = $self->routes;

        # Load some modules
        $self->load_module("MongoDB");
        $self->load_module("Validate");

        # Add all route destinations
        $r->add("/one", "one");
        ...

    }

=head2 load_module

C<load_module($name, %options)>

Used to load a module. All modules should be under the C<Kelp::Module::>
namespace. If they are not, their class name must be prepended with C<+>.

    $self->load_module("Redis", server => '127.0.0.1');
    # Will look for and load Kelp::Module::Redis

Options for the module may be specified after its name, or in the
C<modules_init> hash in the config. Precedence is given to the
inline options.
See L<Kelp::Module> for more information on making and using modules.

=head2 build_context

This method is used to build the context. By default, it's used lazily by
L</context_obj> attribute. It can be overridden to modify how context is built.

=head2 build_request

This method is used to create the request object for each HTTP request. It
returns an instance of the class defined in the request_obj attribute (defaults to
L<Kelp::Request>), initialized with the current request's environment. You can
override this method to use a custom request module if you need to do something
interesting. Though there is a provided attribute that can be used to overide
the class of the object used.

    package MyApp;
    use MyApp::Request;

    sub build_request {
        my ( $self, $env ) = @_;
        return MyApp::Request->new( app => $app, env => $env );
    }

    # Now each request will be handled by MyApp::Request

=head2 build_response

This method creates the response object, e.g. what an HTTP request will return.
By default the object created is L<Kelp::Response> though this can be
overwritten via the respone_obj attribute. Much like L</build_request>, the
response can also be overridden to use a custom response object if you need
something completely custom.

=head2 before_dispatch

Override this method to modify the behavior before a route is handled. The
default behavior is to log access (if C<logger> is available).

    package MyApp;

    sub before_dispatch {
        my ( $self, $destination ) = @_;

        # default access logging is disabled
    }

The C<$destination> param will depend on the routes implementation used. The
default router will pass the unchanged L<Kelp::Routes::Pattern/to>. If
possible, it will be run on the controller object (allowing overriding
C<before_dispatch> on controller classes).

=head2 after_unrendered

Override this method to control what's going to happen when a route has been
found but it did not render anything. The default behavior is to render page
404 (if only bridges are found) or throw an error.

This hook will get passed an array reference to all matched routes, so you can
inspect them at will to decide what to do. It's strongly recommended to still
render 404 if the last match is a bridge (as is default).

    sub after_unrendered {
        my ( $self, $matches ) = @_;

        if ($matches->[-1]->bridge) {
            $self->res->render_404;
        }
        else {
            # do something custom
        }
    }

=head2 before_finalize

Override this method to modify the response object just before it gets
finalized.

    package MyApp;

    sub before_finalize {
        my $self = shift;
        $self->res->set_header("X-App-Name", "MyApp");
    }

    ...

The above is an example of how to insert a custom header into the response of
every route.


=head2 run

This method builds and returns the PSGI app. You can override it to get more
control over PSGI representation of the app.

=head2 param

A shortcut to C<$self-E<gt>req-E<gt>param>:

    sub some_route {
        my $self = shift;
        if ( $self->param('age') > 18 ) {
            $self->can_watch_south_path(1);
        }
    }

This function can be tricky to use because of context sensivity. See
L<Kelp::Request/param> for more information and examples.

=head2 session

A shortcut to C<$self-E<gt>req-E<gt>session>. Take a look at L<Kelp::Request/session>
for more information and examples.

=head2 stash

Provides safe access to C<$self-E<gt>req-E<gt>stash>. When called without
arguments, it will return the stash hash. If called with a single argument, it
will return the value of the corresponding key in the stash.
See L<Kelp::Request/stash> for more information and examples.

=head2 named

Provides safe access to C<$self-E<gt>req-E<gt>named>. When called without
arguments, it will return the named hash. If called with a single argument, it
will return the value of the corresponding key in the named hash.
See L<Kelp::Request/named> for more information and examples.

=head2 url_for

A safe shortcut to C<$self-E<gt>routes-E<gt>url>. Builds a URL from path and
arguments.

    sub build {
        my $self = shift;
        $self->routes->add("/:name/:id", { name => 'name', to => sub {
            ...
        }});
    }

    sub check {
        my $self = shift;
        my $url_for_name = $self->url_for('name', name => 'jake', id => 1003);
        $self->res->redirect_to( $url_for_name );
    }

=head2 abs_url

Same as L</url_for>, but returns the full absolute URI for the current
application (based on configuration).

=head2 is_production

Returns whether the application is in production mode. Checks if L</mode> is
either C<deployment> or C<production>.

=head2 get_encoder

    my $json_encoder = $self->get_encoder('json');

Gets an instance of a given encoder. It takes two arguments:

=over

=item * type of the encoder module (eg. C<json>)

=item * optional name of the encoder (default is C<default>)

=back

It will get extra config (if available) from C<encoders.TYPE.NAME>
configuration hash. Will instantiate the encoder just once and then reuse it.
Croaks when there is no such encoder type.

Example new JSON encoder type defined in config:

    encoders => {
        json => {
            not_very_pretty => {
                pretty => 0,
            },
        },
    },

=head2 NEXT_APP

Helper method for giving Kelp back the control over PSGI application. It must
be used when declaring route-level middleware. It is context-independent and
can be called from C<Kelp> package.

    use Plack::Builder;

    builder {
        enable 'SomeMiddleware';
        Kelp->NEXT_APP;
    }

Internally, it uses C<kelp.execution_chain> PSGI environment to dynamically
construct a wrapped PSGI app without too much overhead.

=head1 AUTHOR

Stefan Geneshky - minimal <at> cpan.org

=head1 LICENSE

This module and all the modules in this package are governed by the same license
as Perl itself.

=cut

