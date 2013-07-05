package Kelp;

use Kelp::Base;

use Carp 'longmess';
use FindBin;
use Encode;
use Try::Tiny;
use Data::Dumper;
use Sys::Hostname;
use Plack::Util;
use Kelp::Request;
use Kelp::Response;

our $VERSION = 0.4012;

# Basic attributes
attr -host => hostname;
attr  mode => $ENV{KELP_ENV} // $ENV{PLACK_ENV} // 'development';
attr -path => $FindBin::Bin;
attr -name => sub { ( ref( $_[0] ) =~ /(\w+)$/ ) ? $1 : 'Noname' };

# Debug
attr long_error => $ENV{KELP_LONG_ERROR} // 0;

# The charset is UTF-8 unless otherwise instructed
attr -charset => sub {
    $_[0]->config("charset") // 'UTF-8';
};

attr config_module => 'Config';
attr -loaded_modules => sub { {} };

# Each route's request an response objects will
# be put here:
attr req => undef;
attr res => undef;

# Initialization
sub new {
    my $self = shift->SUPER::new(@_);

    # Always load these modules
    $self->load_module( $self->config_module );
    $self->load_module('Routes');

    # Load the modules from the config
    if ( defined( my $modules = $self->config('modules') ) ) {
        $self->load_module($_) for (@$modules);
    }

    $self->build();
    return $self;
}

sub load_module {
    my ( $self, $name, %args ) = @_;

    # Make sure the module was not already loaded
    return if $self->loaded_modules->{$name};

    my $class = Plack::Util::load_class( $name, 'Kelp::Module' );
    my $module = $self->loaded_modules->{$name} = $class->new( app => $self );

    # When loading the Config module itself, we don't have
    # access to $self->config yet. This is why we check if
    # config is available, and if it is, then we pull the
    # initialization hash.
    my $args_from_config = {};
    if ( $self->can('config') ) {
        $args_from_config = $self->config("modules_init.$name") // {};
    }

    $module->build( %$args_from_config, %args );
    return $module;
}

# Override this one to add custom initializations
sub build {
}

# Override to use a custom request object
sub request {
    my ( $self, $env ) = @_;
    return Kelp::Request->new( app => $self, env => $env );
}

# Override to use a custom response object
sub response {
    my $self = shift;
    return Kelp::Response->new( app => $self );
}

# Override to manipulate the end response
sub before_finalize {
    my $self = shift;
    $self->res->header('X-Framework' => 'Perl Kelp');
}

# Override this to wrap more middleware around the app
sub run {
    my $self = shift;
    my $app = sub { $self->psgi(@_) };

    # Add middleware
    if ( defined( my $middleware = $self->config('middleware') ) ) {
        for my $class (@$middleware) {

            # Make sure the middleware was not already loaded
            next if $self->{_loaded_middleware}->{$class}++;

            my $mw = Plack::Util::load_class($class, 'Plack::Middleware');
            my $args = $self->config("middleware_init.$class") // {};
            $app = $mw->wrap( $app, %$args );
        }
    }

    return $app;
}

sub psgi {
    my ( $self, $env ) = @_;

    # Create the request and response objects
    my $req = $self->req( $self->request($env) );
    my $res = $self->res( $self->response );

    # Get route matches
    my $match = $self->routes->match( $req->path, $req->method );

    # None found? Show 404 ...
    if ( !@$match ) {
        $res->render_404;
        return $self->finalize;
    }

    try {

        # Go over the entire route chain
        for my $route (@$match) {
            my $to = $route->to;

            # Check if the destination is valid
            if ( ref($to) && ref($to) ne 'CODE' || !$to ) {
                die 'Invalid destination for ' . $req->path;
            }

            # Check if the destination function exists
            if ( !ref($to) && !exists &$to ) {
                die sprintf( 'Route not found %s for %s', $to, $req->path );
            }

            # Log info about the route
            if ( $self->can('logger') ) {
                $self->logger(
                    'info',
                    sprintf( "%s - %s %s - %s",
                        $req->address, $req->method, $req->path, $to )
                );
            }

            # Eval the destination code
            my $code = ref $to eq 'CODE' ? $to : \&{$to};
            $req->named( $route->named );
            my $data = $code->( $self, @{ $route->param } );

            # Is it a bridge? Bridges must return a true value
            # to allow the rest of the routes to run.
            if ( $route->bridge ) {
                if ( !$data ) {
                    $res->render_401 unless $res->rendered;
                    last;
                }
                next;
            }

            # If the route returned something, then analyze it and render it
            if ( defined $data ) {

                # Handle delayed response if CODE
                return $data if ref($data) eq 'CODE';
                $res->render($data) unless $res->rendered;
            }
        }

        # If nothing got rendered, die with error
        if ( !$self->res->rendered ) {
            die $match->[-1]->to
              . " did not render for method "
              . $req->method;
        }

        $self->finalize;
    }
    catch {
        my $message = $self->long_error ? longmess($_) : $_;

        # Log error
        $self->logger( 'critical', $message ) if $self->can('logger');

        # Render 500
        $self->res->render_500($message);
        $self->finalize;
    };
}

sub finalize {
    my $self = shift;
    $self->before_finalize;
    $self->res->finalize;
}


#----------------------------------------------------------------
# Request and Response shortcuts
#----------------------------------------------------------------
sub param { shift->req->param(@_) }

sub session { shift->req->session(@_) }

sub stash {
    my $self = shift;
    @_ ? $self->req->stash->{$_[0]} : $self->req->stash;
}

sub named {
    my $self = shift;
    @_ ? $self->req->named->{$_[0]} : $self->req->named;
}

#----------------------------------------------------------------
# Utility
#----------------------------------------------------------------

sub url_for {
    my ( $self, $name, @args ) = @_;
    my $result = $name;
    try { $result = $self->routes->url( $name, @args ) };
    return $result;
}

sub abs_url {
    my ( $self, $name, @args ) = @_;
    my $url = $self->url_for( $name, @args );
    return URI->new_abs( $url, $self->config('app_url') )->as_string;
}

1;

__END__

=pod

=head1 NAME

Kelp - A web framework light, yet rich in nutrients.

=head1 SYNOPSIS

First ...

    # lib/MyApp.pm
    package MyApp;
    use parent 'Kelp';

    sub build {
        my $self = shift;
        my $r = $self->routes;
        $r->add( "/hello", sub { "Hello, world!" } );
        $r->add( '/hello/:name', 'greet' );
    }

    sub greet {
        my ( $self, $name ) = @_;
        "Hello, $name!";
    }

    1;

Then ...

    # app.psgi
    use MyApp;
    my $app = MyApp->new;
    $app->run;

Finally ...

    > plackup app.psgi

Or, for quick prototyping use L<Kelp::Less>:

    # app.psgi
    use Kelp::Less;

    get '/hello/?name' => sub {
        my ( $self, $name ) = @_;
        "Hello " . $name // 'world';
    };

    run;

=head1 DESCRIPTION

If you're going to be deploying a Perl based web application, chances are that
you will be using Plack. Plack has almost all necessary tools to create and
maintain a healthy web app. Tons of middleware is written for it, and there are
several very well tested high performance preforking servers, such as Starman.

Plack, however, is not a web framework, hence its creators have intentionally
omitted adding certain components. This is where Kelp gets to shine. It provides
a layer on top of Plack and puts everything together into a complete web
framework.

Kelp provides:

=over

=item

B<Advanced Routing>. Create intricate, yet simple ways to capture HTTP requests
and route them to their designated code. Use explicit and optional named
placeholders, wildcards, or just regular expressions.

=cut

=item

B<Flexible Configuration>. Use different configuration file for each
environment, e.g. development, deployment, etc. Merge a temporary configuration
into your current one for testing and debugging purposes.

=cut

=item

B<Enhanced Logging>. Log messages at different levels of emergency. Log to a
file, screen, or anything supported by Log::Dispatcher.

=cut

=item

B<Powerful Rendering>. Use the built-in auto-rendering logic, or the template
module of your choice to return rich text, html and JSON responses.

=cut

=item

B<JSON encoder/decoder>. If you're serious about your back-end code. Kelp comes
with JSON, but you can easily plug in JSON::XS or any decoder of your choice.

=cut

=item

B<Extendable Core>. Kelp uses pluggable modules for everything. This allows
anyone to add a module for a custom interface. Writing Kelp modules is a
pleasant and fulfilling activity.

=cut

=item

B<Sleek Testing>. Kelp takes Plack::Test and wraps it in an object oriented
class of convenience methods. Testing is done via sending requests to your
routes, then analyzing the response.

=cut

=back

=head1 WHY KELP?

What makes Kelp different from the other Perl micro web frameworks? There are a
number of fine web frameworks on CPAN, and most of them provide a complete
platform for web app building. Most of them, however, bring their deployment code,
and aim to write their own processing mechanisms. Kelp, on the other hand, is heavily
I<Plack>-centric. It uses Plack as its foundation layer, and it builds the web
framework on top of it. C<Kelp::Request> is an extension of C<Plack::Request>,
C<Kelp::Response> is an extension of C<Plack::Response>.

This approach of extending current CPAN code puts familiar and well tested
tools in the hands of the application developer, while keeping familiar syntax
and work flow.

Kelp is a team player and it uses several popular, trusted CPAN modules for its
internals. At the same time it doesn't include modules that it doesn't need,
just because they are considered trendy. It does its best to keep a lean profile
and a small footprint, and it's completely object manager agnostic.

=head1 CREATING A NEW WEB APP

=head2 Using the C<Kelp> script

The easiest way to create the directory structure and a general application
skeleton is by using the C<Kelp> script, which comes with this package.

    > Kelp MyApp

This will create C<lib/MyApp.pm>, C<app.psgi> and some other files (explained
below).

To create a L<Kelp::Less> app, use:

    > Kelp --less MyApp

Get help by typing:

    > Kelp --help

=head2 Directory structure

Before you begin writing the internals of your app, you need to create the
directory structure either by hand, or by using the above described C<Kelp>
utility script.

     .
     |--/lib
     |   |--MyApp.pm
     |   |--/MyApp
     |
     |--/conf
     |   |--config.pl
     |   |--test.pl
     |   |--development.pl
     |   |--deployment.pl
     |
     |--/view
     |--/log
     |--/t
     |--app.psgi

=over

=item B</lib>

The C<lib> folder contains your application modules and any local modules
that you want your app to use.

=cut

=item B</conf>

The C<conf> folder is where Kelp will look for configuration files. You need one
main file, named C<config.pl>. You can also add other files that define different
running environments, if you name them I<environment>C<.pl>. Replace
I<environment> with the actual name of the environment.
To change the running environment, you can specify the app C<mode>, or you can
set the C<PLACK_ENV> environment variable.

    my $app = MyApp->new( mode => 'development' );

or

    > PLACK_ENV=development plackup app.psgi

=cut

=item B</view>

This is where the C<Template> module will look for template files.

=cut

=item B</log>

This is where the C<Logger> module will create C<error.log>, C<debug.log> and
any other log files that were defined in the configuration.

=cut

=item B</t>

The C<t> folder is traditionally used to hold test files. It is up to you to use
it or not, although we strongly recommend that you write some automated test
units for your web app.

=cut

=item B<app.psgi>

This is the L<PSGI> file, of the app, which you will deploy. In it's most basic
form it should look like this:

    use lib '../lib';
    use MyApp;

    my $app = MyApp->new;
    $app->run;

=cut

=back

=head2 The application classes

Your application's classes should be put in the C<lib/> folder. The main class,
in our example C<MyApp.pm>, initializes any modules and variables that your
app will use. Here is an example that uses C<Moose> to create lazy attributes
and initialize a database connection:

    package MyApp;
    use Moose;

    has dbh => (
        is      => 'ro',
        isa     => 'DBI',
        lazy    => 1,
        default => sub {
            my $self   = shift;
            my @config = @{ $self->config('dbi') };
            return DBI->connect(@config);
        }
    );

    sub build {
        my $self = shift;
        $self->routes->add("/read/:id", "read");
    }

    sub read {
        my ( $self, $id ) = @_;
        $self->dbh->selectrow_array(q[
            SELECT * FROM problems
            WHERE id = ?
        ], $id);
    }

    1;

What is happening here?

=over

=item

First, we create a lazy attribute and instruct it to connect to DBI. Notice that
we have access to the current app and all of its internals via the C<$self>
variable. Notice also that the reason we define C<dbh> as a I<lazy> attribute
is that C<config> will not yet be initialized. All modules are initialized upon
the creation of the object instance, e.g. when we call C<MyApp-E<gt>new>;

=cut

=item

Then, we override Kelp's L</build> subroutine to create a single route
C</read/:id>, which is assigned to the subroutine C<read> in the current class.

=cut

=item

The C<read> subroutine, takes C<$self> and C<$id> (the named placeholder from the
path), and uses C<$self-E<gt>dbh> to retrieve data.

=cut

=back

I<A note about object managers:> The above example uses L<Moose>. It is entirely
up to you to use Moose, another object manager, or no object manager at all.
The above example will be just as successful if you used our own little
L<Kelp::Base>:

    package MyApp;
    use Kelp::Base 'Kelp';

    attr dbi => sub {
        ...
    };

    1;

=head2 Routing

Kelp uses a powerful and very flexible router. Traditionally, it is also light
and consists of less than 300 lines of code (comments included). You are
encouraged to read L<Kelp::Routes>, but here are some key points. All examples
are assumed to be inside the L</build> method and C<$r> is equal to
C<$self-E<gt>routes>:

=head3 Destinations

You can direct HTTP paths to subroutines in your classes or, you can use inline
code.

    $r->add( "/home", "home" );  # goes to sub home
    $r->add( "/legal", "legal#view" ); # goes to MyApp::Legal::view
    $r->add( "/about", sub { "Content for about" }); # inline

=head3 Restrict HTTP methods

Make a route only catch a specific HTTP method:

    $r->add( [ POST => '/update' ], "update_user" );

=head3 Named captures

Using regular expressions is so Perl. Sometimes, however, it gets a little
overwhelming. Use named paths if you anticipate that you or someone else will
ever want to maintain your code.

=head4 Explicit

    $r->add( "/update/:id", "update" );

    # Later
    sub update {
        my ( $self, $id ) = @_;
        # Do something with $id
    }

=head4 Optional

    $r->add( "/person/?name", sub {
        my ( $self, $name ) = @_;
        return "I am " . $name // "nobody";
    });

This will handle C</person>, C</person/> and C</person/jack>.

=head4 Wildcards

    $r->add( '/*article/:id', 'articles#view' );

This will handle C</bar/foo/baz/500> and send it to C<MyApp::Articles::view>
with parameters C<$article> equal to C<bar/foo/baz> and C<$id> equal to 500.

=head3 Placeholder restrictions

Paths' named placeholders can be restricted by providing regular expressions.

    $r->add( '/user/:id', {
        check => { id => '\d+' },
        to    => "users#get"
    });

    # Matches /user/1000, but not /user/abc

=head3 Placeholder defaults

This only applies to optional placeholders, or those prefixed with a question mark.
If a default value is provided for any of them, it will be used in case the
placeholder value is missing.

    $r->add( '/:id/?other', defaults => { other => 'info' } );

    # GET /100;
    # { id => 100, other => 'info' }

    # GET /100/delete;
    # { id => 100, other => 'delete' }

=head3 Bridges

A I<bridge> is a route that has to return a true value in order for the next
route in line to be processed.

    $r->add( '/users', { to => 'Users::auth', bridge => 1 } );
    $r->add( '/users/:action' => 'Users::dispatch' );

See L<Kelp::Routes/BRIDGES> for more information.

=head3 URL building

Each path can be given a name and later a URL can be built using that name and
the necessary arguments.

    $r->add( "/update/:id", { name => 'update', to => 'user#update' } );

    # Later

    my $url = $self->route->url('update', id => 1000); # /update/1000

=head2 Quick development using Kelp::Less

For writing quick experimental web apps and to reduce the boiler plate, one
could use L<Kelp::Less>. In this case all of the code can be put in C<app.psgi>:
Look up the POD for C<Kelp::Less> for many examples, but to get you started off,
here is a quick one:

    # app.psgi
    use Kelp:::Less;

    get '/api/:user/?action' => sub {
        my ( $self, $user, $action ) = @_;
        my $json = {
            success => \1,
            user    => $user,
            action  => $action // 'ask'
        };
        return $json;
    };

    run;

=head2 Adding middleware

Kelp, being Plack-centric, will let you easily add middleware. There are three
possible ways to add middleware to your application, and all three ways can be
used separately or together.

=head3 Using the configuration

Adding middleware in your configuration is probably the easiest and best way for
you. This way you can load different middleware for each running mode, e.g.
C<Debug> in development only.

Add middleware names to the C<middleware> array in your configuration file and
the corresponding initializing arguments in the C<middleware_init> hash:

    # conf/development.pl
    {
        middleware      => [qw/Session Debug/],
        middleware_init => {
            Session => { store => 'File' }
        }
    }

The middleware will be added in the order you specify in the C<middleware>
array.

=head3 In C<app.psgi>:

    # app.psgi
    use MyApp;
    use Plack::Builder;

    my $app = MyApp->new();

    builder {
        enable "Plack::Middleware::ContentLength";
        $app->run;
    };

=head3 By overriding the L</run> subroutine in C<lib/MyApp.pm>:

Make sure you call C<SUPER> first, and then wrap new middleware around the
returned app.

    # lib/MyApp.pm
    sub run {
        my $self = shift;
        my $app = $self->SUPER::run(@_);
        Plack::Middleware::ContentLength->wrap($app);
    }

Note that any middleware defined in your config file will be added first.

=head2 Deploying

Deploying a Kelp application is done the same way any other Plack application is
deployed:

    > plackup -E deployment -s Starman app.psgi

=head2 Testing

Kelp provides a test class called C<Kelp::Test>. It is object oriented, and all
methods return the C<Kelp::Test> object, so they can be chained together.
Testing is done by sending HTTP requests to an already built application and
analyzing the response. Therefore, each test usually begins with the
L<Kelp::Test/request> method, which takes a single L<HTTP::Request> parameter.
It sends the request to the web app and saves the response as an
L<HTTP::Response> object.

    # file t/test.t
    use MyApp;
    use Kelp::Test;
    use Test::More;
    use HTTP::Request::Common;

    my $app = MyApp->new( mode => 'test' );
    my $t = Kelp::Test->new( app => $app );

    $t->request( GET '/path' )
      ->code_is(200)
      ->content_is("It works");

    $t->request( POST '/api' )
      ->json_cmp({auth => 1});

    done_testing;

What is happening here?

=over

=item

First, we create an instance of the web application class, which we have
previously built and placed in the C<lib/> folder. We set the mode of the app to
C<test>, so that file C<conf/test.pl> overrides the main configuration.
The test configuration can contain anything you see fit. Perhaps you want to
disable certain modules, or maybe you want to make DBI connect to a different
database.

=cut

=item

Second, we create an instance of the C<Kelp::Test> class and tell it that it
will perform all tests using our C<$app> instance.

=cut

=item

At this point we are ready to send requests to the app via the
L<request|Kelp::Test/request> method. It takes only one argument, an
HTTP::Request object. It is very convenient to use the L<HTTP::Request::Common>
module here, because you can create common requests using abridged syntax,
i.e. C<GET>, C<POST>, etc.  The line C<$t-E<gt>request( GET '/path' )> fist
creates a HTTP::Request GET object, and then passes it to the C<request> method.

=cut

=item

After we send the request, we can test the response using any of the C<Test::>
modules, or via the methods provided by L<Kelp::Test>.
In the above example, we test if we got a code 200 back from C</path> and if the
returned content was C<It works>.

=cut

=back

Run the rest as usual, using C<prove>:

    > prove -l t/test.t

Take a look at the L<Kelp::Test> for details and more examples.

=head2 Building an HTTP response

Kelp contains an elegant module, called L<Kelp::Response>, which extends
C<Plack::Response> with several useful methods. Most methods return C<$self>
after they do the required job.
For the sake of the examples below, let's assume that all of the code is located
inside a route definition.

=head3 Automatic content type

Your routes don't always have to set the C<response> object. You could just
return a simple scalar value or a reference to a hash, array or anything that
can be converted to JSON.

    # Content-type automatically set to "text/html"
    sub text_route {
        return "There, there ...";
    }

    # Content-type automatically set to "application/json"
    sub json_route {
        return { error => 1,  message => "Fail" };
    }

=head3 Rendering text

    # Render simple text
    $self->res->text->render("It works!");

=head3 Rendering HTML

    $self->res->html->render("<h1>It works!</h1>");

=head3 Custom content type

    $self->res->set_content_type('image/png');

=head3 Return 404 or 500 errors

    sub some_route {
        my $self = shift;
        if ($missing) {
            return $self->res->render_404;
        }
        if ($broken) {
            return $self->res->render_500;
        }
    }

=head3 Templates

    sub hello {
        my ( $self, $name ) = @_;
        $self->res->template( 'hello.tt', { name => $name } );
    }

The above example will render the contents of C<hello.tt>, and it will set the
content-type to C<text/html>. To set a different content-type, use
C<set_content_type> or any of its aliases:

    sub hello_txt {
        my ( $self, $name ) = @_;
        $self->res->text->template( 'hello_txt.tt', { name => $name } );
    }

=head3 Headers

    $self->set_header( "X-Framework", "Kelp" )->render( { success => \1 } );

=head3 Serving static files

If you want to serve static pages, you can use the L<Plack::Middleware::Static>
middleware that comes with Plack. Here is an example configuration that serves
files in your C<public> folder (under the Kelp root folder) from URLs that
begin with C</public>:

    # conf/config.pl
    {
        middleware      => [qw/Static/],
        middleware_init => {
            Static => {
                path => qr{^/public/},
                root => '.',
            }
        }
    };

=head3 Uploading files

File uploads are handled by L<Kelp::Request>, which inherits Plack::Request
and has its C<uploads|Plack::Request/uploads> property. The uploads propery returns a
reference to a hash containing all uploads.

    sub upload {
        my $self = shift;
        my $uploads  = $self->req->uploads;

        # Now $uploads is a hashref to all uploads
        ...
    }

For L<Kelp::Less>, then you can use the C<req> reserved word:

    get '/upload' => sub {
        my $uploads = req->uploads;
    };

=head3 Delayed responses

To send a delayed response, have your route return a subroutine.

    sub delayed {
        my $self = shift;
        return sub {
            my $responder = shift;
            $self->res->code(200);
            $self->res->text->body("Better late than never.");
            $responder->($self->res->finalize);
        };
    }

See the L<PSGI|PSGI/Delayed-Response-and-Streaming-Body> pod for more
information and examples.

=head2 Pluggable modules

Kelp can be extended using custom I<modules>. Each new module must be a subclass
of the C<Kelp::Module> namespace. Modules' job is to initialize and register new
methods into the web application class. The following is the full code of the
L<Kelp::Module::JSON> for example:

    package Kelp::Module::JSON;

    use Kelp::Base 'Kelp::Module';
    use JSON;

    sub build {
        my ( $self, %args ) = @_;
        my $json = JSON->new;
        $json->property( $_ => $args{$_} ) for keys %args;
        $self->register( json => $json );
    }

    1;

What is happening here?

=over

=item

First we create a class C<Kelp::Module::JSON> which inherits C<Kelp::Module>.

=cut

=item

Then, we override the C<build> method (of C<Kelp::Module>), create a new JSON
object and register it into the web application via the C<register> method.

=cut

=back

If we instruct our web application to load the C<JSON> module, it will have a
new method C<json> which will be a link to the C<JSON> object initialized in the
module.

See more exampled and POD at L<Kelp::Module>.

=head3 How to load modules using the config

There are two modules that are B<always> loaded by each application instance.
Those are C<Config> and C<Routes>. The reason behind this is that each and every
application always needs a router and configuration.
All other modules must be loaded either using the L</load_module> method, or
using the C<modules> key in the configuration. The default configuration already
loads these modules: C<Template>, C<Logger> and C<JSON>. Your configuration can
remove some and/or add others. The configuration key C<modules_init> may contain
hashes with initialization arguments. See L<Kelp::Module> for configuration
examples.

=head1 ATTRIBUTES

=head2 hostname

Gets the current hostname.

    sub some_route {
        my $self = shift;
        if ( $self->hostname eq 'prod-host' ) {
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

This can come handy if your module does more than just registering a new method
into the application. Then, you can use its object instance to do access that
additional functionality.


=head2 path

Gets the current path of the application. That would be the path to C<app.psgi>

=head2 name

Gets or sets the name of the application. If not set, the name of the main
class will be used.

    my $app = MyApp->new( name => 'Twittar' );

=head2 charset

Sets of gets the encoding charset of the app. It will be C<UTF-8>, if not set to
anything else. The charset could also be changed in the config files.

=head2 long_error

When a route dies, Kelp will by default display a short error message. Set this
attribute to a true value, if you need to see a full stack trace of the error.
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

=head2 res

This attribute only makes sense if called within a route definition. It will
contain a reference to the current L<Kelp::Response> instance.

    sub some_route {
        my $self = shift;
        $self->res->json->render( { success => 1 } );
    }

=head1 METHODS

=head2 build

On it's own the C<build> method doesn't do anything. It is called by the
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

Used to load a module. All modules must be under the C<Kelp::Module::>
namespace.

    $self->load_module("Redis", server => '127.0.0.1');
    # Will look for and load Kelp::Module::Redis

Options for the module may be specified after its name, or in the
C<modules_init> hash in the config. The precedence is given to the
inline options.
See L<Kelp::Module> for more information on making and using modules.

=head2 request

This method is used to create the request object for each HTTP request. It
returns an instance of L<Kelp::Request>, initialized with the current request's
environment. You can override this method to use a custom request module.

    package MyApp;
    use MyApp::Request;

    sub request {
        my ( $self, $env ) = @_;
        return MyApp::Requst->new( app => $app, env => $env );
    }

    # Now each request will be handled by MyApp::Request

=head2 before_finalize

Override this method, to modify the response object just before it gets
finalized.

    package MyApp;

    sub before_finalize {
        my $self = shift;
        $self->res->set_header("X-App-Name", "MyApp");
    }

    ...

The above is an example of how to insert a custom header into the response of
every route.

=head2 response

This method creates the response object, e.g. what an HTTP request will return.
By default the object created is L<Kelp::Response>. Much like L</request>, the
response can also be overridden to use a custom response object.

=head2 run

This method builds and returns the PSGI app. You can override it in order to
include middleware. See L</Adding middleware> for an example.

=head2 param

A shortcut to C<$self-E<gt>req-E<gt>param>:

    sub some_route {
        my $self = shift;
        if ( $self->param('age') > 18 ) {
            $self->can_watch_south_path(1);
        }
    }

See L<Kelp::Request> for more information and examples.

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

=head1 SUPPORT

=over

=item * GitHub: https://github.com/naturalist/kelp

=item * Mailing list: https://groups.google.com/forum/?fromgroups#!forum/perl-kelp

=back

=head1 AUTHOR

Stefan Geneshky - minimal@cpan.org

=head1 CONTRIBUTORS

Gurunandan Bhat - gbhat@pobox.com

=head1 LICENSE

This module and all the modules in this package are governed by the same license
as Perl itself.

=cut
