# NAME

Kelp - A web framework light, yet rich in nutrients.

# SYNOPSIS

First ...

```perl
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
```

Then ...

```perl
# app.psgi
use MyApp;
my $app = MyApp->new;
$app->run;
```

Finally ...

```
> plackup app.psgi
```

Or, for quick prototyping use [Kelp::Less](https://metacpan.org/pod/Kelp::Less):

```perl
# app.psgi
use Kelp::Less;

get '/hello/?name' => sub {
    my ( $self, $name ) = @_;
    "Hello " . $name // 'world';
};

run;
```

# DESCRIPTION

If you're going to be deploying a Perl based web application, chances are that
you will be using Plack. Plack has almost all necessary tools to create and
maintain a healthy web app. Tons of middleware is written for it, and there are
several very well tested high performance preforking servers, such as Starman.

Plack, however, is not a web framework, hence its creators have intentionally
omitted adding certain components. This is where Kelp gets to shine. It provides
a layer on top of Plack and puts everything together into a complete web
framework.

Kelp provides:

- **Advanced Routing**. Create intricate, yet simple ways to capture HTTP requests
and route them to their designated code. Use explicit and optional named
placeholders, wildcards, or just regular expressions.
- **Flexible Configuration**. Use different configuration file for each
environment, e.g. development, deployment, etc. Merge a temporary configuration
into your current one for testing and debugging purposes.
- **Enhanced Logging**. Log messages at different levels of emergency. Log to a
file, screen, or anything supported by Log::Dispatcher.
- **Powerful Rendering**. Use the built-in auto-rendering logic, or the template
module of your choice to return rich text, html and JSON responses.
- **JSON encoder/decoder**. Kelp comes with JSON, but you can easily plug in JSON::XS
or any decoder of your choice.
- **Extendable Core**. Kelp uses pluggable modules for everything. This allows
anyone to add a module for a custom interface. Writing Kelp modules is easy.
- **Sleek Testing**. Kelp takes Plack::Test and wraps it in an object oriented
class of convenience methods. Testing is done via sending requests to your
routes, then analyzing the response.

# WHY KELP?

What makes Kelp different from the other Perl micro web frameworks? There are a
number of fine web frameworks on CPAN, and most of them provide a complete
platform for web app building. Most of them, however, bring their deployment code,
and aim to write their own processing mechanisms. Kelp, on the other hand, is heavily
_Plack_-centric. It uses Plack as its foundation layer, and it builds the web
framework on top of it. `Kelp::Request` is an extension of `Plack::Request`,
`Kelp::Response` is an extension of `Plack::Response`.

This approach of extending current CPAN code puts familiar and well tested
tools in the hands of the application developer, while keeping familiar syntax
and work flow.

Kelp is a team player and it uses several popular, trusted CPAN modules for its
internals. At the same time it doesn't include modules that it doesn't need,
just because they are considered trendy. It does its best to keep a lean profile
and a small footprint, and it's completely object manager agnostic.

# CREATING A NEW WEB APP

## Using the `Kelp` script

The easiest way to create the directory structure and a general application
skeleton is by using the `Kelp` script, which comes with this package.

```
> Kelp MyApp
```

This will create `lib/MyApp.pm`, `app.psgi` and some other files (explained
below).

To create a [Kelp::Less](https://metacpan.org/pod/Kelp::Less) app, use:

```
> Kelp --less MyApp
```

Get help by typing:

```
> Kelp --help
```

## Directory structure

Before you begin writing the internals of your app, you need to create the
directory structure either by hand, or by using the above described `Kelp`
utility script.

```
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
```

- **/lib**

    The `lib` folder contains your application modules and any local modules
    that you want your app to use.

- **/conf**

    The `conf` folder is where Kelp will look for configuration files. You need one
    main file, named `config.pl`. You can also add other files that define different
    running environments, if you name them _environment_`.pl`. Replace
    _environment_ with the actual name of the environment.
    To change the running environment, you can specify the app `mode`, or you can
    set the `PLACK_ENV` environment variable.

    ```perl
    my $app = MyApp->new( mode => 'development' );
    ```

    or

    ```
    > PLACK_ENV=development plackup app.psgi
    ```

- **/view**

    This is where the `Template` module will look for template files.

- **/log**

    This is where the `Logger` module will create `error.log`, `debug.log` and
    any other log files that were defined in the configuration.

- **/t**

    The `t` folder is traditionally used to hold test files. It is up to you to use
    it or not, although we strongly recommend that you write some automated test
    units for your web app.

- **app.psgi**

    This is the [PSGI](https://metacpan.org/pod/PSGI) file, of the app, which you will deploy. In it's most basic
    form it should look like this:

    ```perl
    use lib '../lib';
    use MyApp;

    my $app = MyApp->new;
    $app->run;
    ```

## The application classes

Your application's classes should be put in the `lib/` folder. The main class,
in our example `MyApp.pm`, initializes any modules and variables that your
app will use. Here is an example that uses `Moose` to create lazy attributes
and initialize a database connection:

```perl
package MyApp;

use parent Kelp;
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
```

What is happening here?

- First, we create a lazy attribute and instruct it to connect to DBI. Notice that
we have access to the current app and all of its internals via the `$self`
variable. Notice also that the reason we define `dbh` as a _lazy_ attribute
is that `config` will not yet be initialized. All modules are initialized upon
the creation of the object instance, e.g. when we call `MyApp->new`;
- Then, we override Kelp's ["build"](#build) subroutine to create a single route
`/read/:id`, which is assigned to the subroutine `read` in the current class.
- The `read` subroutine, takes `$self` and `$id` (the named placeholder from the
path), and uses `$self->dbh` to retrieve data.

_A note about object managers:_ The above example uses [Moose](https://metacpan.org/pod/Moose). It is entirely
up to you to use Moose, another object manager, or no object manager at all.
The above example will be just as successful if you used our own little
[Kelp::Base](https://metacpan.org/pod/Kelp::Base):

```perl
package MyApp;
use Kelp::Base 'Kelp';

attr dbi => sub {
    ...
};

1;
```

## Routing

Kelp uses a powerful and very flexible router. Traditionally, it is also light
and consists of less than 300 lines of code (comments included). You are
encouraged to read [Kelp::Routes](https://metacpan.org/pod/Kelp::Routes), but here are some key points. All examples
are assumed to be inside the ["build"](#build) method and `$r` is equal to
`$self->routes`:

### Destinations

You can direct HTTP paths to subroutines in your classes or, you can use inline
code.

```perl
$r->add( "/home", "home" );  # goes to sub home
$r->add( "/legal", "Legal::view" ); # goes to MyApp::Legal::view
$r->add( "/about", sub { "Content for about" }); # inline
```

### Restrict HTTP methods

Make a route only catch a specific HTTP method:

```perl
$r->add( [ POST => '/update' ], "update_user" );
```

### Named captures

Using regular expressions is so Perl. Sometimes, however, it gets a little
overwhelming. Use named paths if you anticipate that you or someone else will
ever want to maintain your code.

#### Explicit

```perl
$r->add( "/update/:id", "update" );

# Later
sub update {
    my ( $self, $id ) = @_;
    # Do something with $id
}
```

#### Optional

```perl
$r->add( "/person/?name", sub {
    my ( $self, $name ) = @_;
    return "I am " . $name // "nobody";
});
```

This will handle `/person`, `/person/` and `/person/jack`.

#### Wildcards

```
$r->add( '/*article/:id', 'Articles::view' );
```

This will handle `/bar/foo/baz/500` and send it to `MyApp::Articles::view`
with parameters `$article` equal to `bar/foo/baz` and `$id` equal to 500.

### Placeholder restrictions

Paths' named placeholders can be restricted by providing regular expressions.

```perl
$r->add( '/user/:id', {
    check => { id => '\d+' },
    to    => "Users::get"
});

# Matches /user/1000, but not /user/abc
```

### Placeholder defaults

This only applies to optional placeholders, or those prefixed with a question mark.
If a default value is provided for any of them, it will be used in case the
placeholder value is missing.

```perl
$r->add( '/:id/?other', defaults => { other => 'info' } );

# GET /100;
# { id => 100, other => 'info' }

# GET /100/delete;
# { id => 100, other => 'delete' }
```

### Bridges

A _bridge_ is a route that has to return a true value in order for the next
route in line to be processed.

```perl
$r->add( '/users', { to => 'Users::auth', bridge => 1 } );
$r->add( '/users/:action' => 'Users::dispatch' );
```

See ["BRIDGES" in Kelp::Routes](https://metacpan.org/pod/Kelp::Routes#BRIDGES) for more information.

### URL building

Each path can be given a name and later a URL can be built using that name and
the necessary arguments.

```perl
$r->add( "/update/:id", { name => 'update', to => 'User::update' } );

# Later

my $url = $self->route->url('update', id => 1000); # /update/1000
```

## Reblessing the app into a controller class

All of the examples here show routes which take an instance of the web
application as a first parameter. This is true even if those routes live in
another class. To rebless the app instance into the controller class instance,
use the custom router class [Kelp::Router::Controller](https://metacpan.org/pod/Kelp::Router::Controller).

### Step 1: Specify the custom router class in the config

```perl
# config.pl
{
    modules_init => {
        Routes => {
            router => 'Controller'
        }
    }
}
```

### Step 2: Create a main controller class

This class must inherit from Kelp.

```perl
# lib/MyApp/Controller.pm
package MyApp::Controller;
use Kelp::Base 'MyApp';

# Now $self is an instance of 'MyApp::Controller';
sub service_method {
    my $self = shift;
    ...;
}

1;
```

### Step 3: Create any number of controller classes

They all must inherit from your main controller class.

```perl
# lib/MyApp/Controller/Users.pm
package MyApp::Controller::Users;
use Kelp::Base 'MyApp::Controller';

# Now $self is an instance of 'MyApp::Controller::Users'
sub authenticate {
    my $self = shift;
    ...;
}

1;
```

## Quick development using Kelp::Less

For writing quick experimental web apps and to reduce the boiler plate, one
could use [Kelp::Less](https://metacpan.org/pod/Kelp::Less). In this case all of the code can be put in `app.psgi`:
Look up the POD for `Kelp::Less` for many examples, but to get you started off,
here is a quick one:

```perl
# app.psgi
use Kelp::Less;

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
```

## Adding middleware

Kelp, being Plack-centric, will let you easily add middleware. There are three
possible ways to add middleware to your application, and all three ways can be
used separately or together.

### Using the configuration

Adding middleware in your configuration is probably the easiest and best way for
you. This way you can load different middleware for each running mode, e.g.
`Debug` in development only.

Add middleware names to the `middleware` array in your configuration file and
the corresponding initializing arguments in the `middleware_init` hash:

```perl
# conf/development.pl
{
    middleware      => [qw/Session Debug/],
    middleware_init => {
        Session => { store => 'File' }
    }
}
```

The middleware will be added in the order you specify in the `middleware`
array.

### In `app.psgi`:

```perl
# app.psgi
use MyApp;
use Plack::Builder;

my $app = MyApp->new();

builder {
    enable "Plack::Middleware::ContentLength";
    $app->run;
};
```

### By overriding the ["run"](#run) subroutine in `lib/MyApp.pm`:

Make sure you call `SUPER` first, and then wrap new middleware around the
returned app.

```perl
# lib/MyApp.pm
sub run {
    my $self = shift;
    my $app = $self->SUPER::run(@_);
    Plack::Middleware::ContentLength->wrap($app);
}
```

Note that any middleware defined in your config file will be added first.

## Deploying

Deploying a Kelp application is done the same way any other Plack application is
deployed:

```
> plackup -E deployment -s Starman app.psgi
```

## Testing

Kelp provides a test class called `Kelp::Test`. It is object oriented, and all
methods return the `Kelp::Test` object, so they can be chained together.
Testing is done by sending HTTP requests to an already built application and
analyzing the response. Therefore, each test usually begins with the
["request" in Kelp::Test](https://metacpan.org/pod/Kelp::Test#request) method, which takes a single [HTTP::Request](https://metacpan.org/pod/HTTP::Request) parameter.
It sends the request to the web app and saves the response as an
[HTTP::Response](https://metacpan.org/pod/HTTP::Response) object.

```perl
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
```

What is happening here?

- First, we create an instance of the web application class, which we have
previously built and placed in the `lib/` folder. We set the mode of the app to
`test`, so that file `conf/test.pl` overrides the main configuration.
The test configuration can contain anything you see fit. Perhaps you want to
disable certain modules, or maybe you want to make DBI connect to a different
database.
- Second, we create an instance of the `Kelp::Test` class and tell it that it
will perform all tests using our `$app` instance.
- At this point we are ready to send requests to the app via the
[request](https://metacpan.org/pod/Kelp::Test#request) method. It takes only one argument, an
HTTP::Request object. It is very convenient to use the [HTTP::Request::Common](https://metacpan.org/pod/HTTP::Request::Common)
module here, because you can create common requests using abridged syntax,
i.e. `GET`, `POST`, etc.  The line `$t->request( GET '/path' )` fist
creates a HTTP::Request GET object, and then passes it to the `request` method.
- After we send the request, we can test the response using any of the `Test::`
modules, or via the methods provided by [Kelp::Test](https://metacpan.org/pod/Kelp::Test).
In the above example, we test if we got a code 200 back from `/path` and if the
returned content was `It works`.

Run the rest as usual, using `prove`:

```
> prove -l t/test.t
```

Take a look at the [Kelp::Test](https://metacpan.org/pod/Kelp::Test) for details and more examples.

## Building an HTTP response

Kelp contains an elegant module, called [Kelp::Response](https://metacpan.org/pod/Kelp::Response), which extends
`Plack::Response` with several useful methods. Most methods return `$self`
after they do the required job.
For the sake of the examples below, let's assume that all of the code is located
inside a route definition.

### Automatic content type

Your routes don't always have to set the `response` object. You could just
return a simple scalar value or a reference to a hash, array or anything that
can be converted to JSON.

```perl
# Content-type automatically set to "text/html"
sub text_route {
    return "There, there ...";
}

# Content-type automatically set to "application/json"
sub json_route {
    return { error => 1,  message => "Fail" };
}
```

### Rendering text

```perl
# Render simple text
$self->res->text->render("It works!");
```

### Rendering HTML

```perl
$self->res->html->render("<h1>It works!</h1>");
```

### Custom content type

```perl
$self->res->set_content_type('image/png');
```

### Return 404 or 500 errors

```perl
sub some_route {
    my $self = shift;
    if ($missing) {
        return $self->res->render_404;
    }
    if ($broken) {
        return $self->res->render_500;
    }
}
```

### Templates

```perl
sub hello {
    my ( $self, $name ) = @_;
    $self->res->template( 'hello.tt', { name => $name } );
}
```

The above example will render the contents of `hello.tt`, and it will set the
content-type to `text/html`. To set a different content-type, use
`set_content_type` or any of its aliases:

```perl
sub hello_txt {
    my ( $self, $name ) = @_;
    $self->res->text->template( 'hello_txt.tt', { name => $name } );
}
```

### Headers

```perl
$self->set_header( "X-Framework", "Kelp" )->render( { success => \1 } );
```

### Serving static files

If you want to serve static pages, you can use the [Plack::Middleware::Static](https://metacpan.org/pod/Plack::Middleware::Static)
middleware that comes with Plack. Here is an example configuration that serves
files in your `public` folder (under the Kelp root folder) from URLs that
begin with `/public`:

```perl
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
```

### Uploading files

File uploads are handled by [Kelp::Request](https://metacpan.org/pod/Kelp::Request), which inherits Plack::Request
and has its `uploads|Plack::Request/uploads` property. The uploads property returns a
reference to a hash containing all uploads.

```perl
sub upload {
    my $self = shift;
    my $uploads  = $self->req->uploads;

    # Now $uploads is a hashref to all uploads
    ...
}
```

For [Kelp::Less](https://metacpan.org/pod/Kelp::Less), then you can use the `req` reserved word:

```perl
get '/upload' => sub {
    my $uploads = req->uploads;
};
```

### Delayed responses

To send a delayed response, have your route return a subroutine.

```perl
sub delayed {
    my $self = shift;
    return sub {
        my $responder = shift;
        $self->res->code(200);
        $self->res->text->body("Better late than never.");
        $responder->($self->res->finalize);
    };
}
```

See the [PSGI](https://metacpan.org/pod/PSGI#Delayed-Response-and-Streaming-Body) pod for more
information and examples.

## Pluggable modules

Kelp can be extended using custom _modules_. Each new module must be a subclass
of the `Kelp::Module` namespace. Modules' job is to initialize and register new
methods into the web application class. The following is the full code of the
[Kelp::Module::JSON](https://metacpan.org/pod/Kelp::Module::JSON) for example:

```perl
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
```

What is happening here?

- First we create a class `Kelp::Module::JSON` which inherits `Kelp::Module`.
- Then, we override the `build` method (of `Kelp::Module`), create a new JSON
object and register it into the web application via the `register` method.

If we instruct our web application to load the `JSON` module, it will have a
new method `json` which will be a link to the `JSON` object initialized in the
module.

See more exampled and POD at [Kelp::Module](https://metacpan.org/pod/Kelp::Module).

### How to load modules using the config

There are two modules that are **always** loaded by each application instance.
Those are `Config` and `Routes`. The reason behind this is that each and every
application always needs a router and configuration.
All other modules must be loaded either using the ["load\_module"](#load_module) method, or
using the `modules` key in the configuration. The default configuration already
loads these modules: `Template`, `Logger` and `JSON`. Your configuration can
remove some and/or add others. The configuration key `modules_init` may contain
hashes with initialization arguments. See [Kelp::Module](https://metacpan.org/pod/Kelp::Module) for configuration
examples.

# ATTRIBUTES

## hostname

Gets the current hostname.

```perl
sub some_route {
    my $self = shift;
    if ( $self->hostname eq 'prod-host' ) {
        ...
    }
}
```

## mode

Sets or gets the current mode. The mode is important for the app to know what
configuration file to merge into the main configuration. See
[Kelp::Module::Config](https://metacpan.org/pod/Kelp::Module::Config) for more information.

```perl
my $app = MyApp->new( mode => 'development' );
# conf/config.pl and conf/development.pl are merged with priority
# given to the second one.
```

## config\_module

Sets of gets the class of the configuration module to be loaded on startup. The
default value is `Config`, which will cause the `Kelp::Module::Config` to get
loaded. See the documentation for [Kelp::Module::Config](https://metacpan.org/pod/Kelp::Module::Config) for more information
and for an example of how to create and use other config modules.

## loaded\_modules

A hashref containing the names and instances of all loaded modules. For example,
if you have these two modules loaded: Template and JSON, then a dump of
the `loaded_modules` hash will look like this:

```perl
{
    Template => Kelp::Module::Template=HASH(0x208f6e8),
    JSON     => Kelp::Module::JSON=HASH(0x209d454)
}
```

This can come handy if your module does more than just registering a new method
into the application. Then, you can use its object instance to do access that
additional functionality.

## path

Gets the current path of the application. That would be the path to `app.psgi`

## name

Gets or sets the name of the application. If not set, the name of the main
class will be used.

```perl
my $app = MyApp->new( name => 'Twittar' );
```

## charset

Sets of gets the encoding charset of the app. It will be `UTF-8`, if not set to
anything else. The charset could also be changed in the config files.

## long\_error

When a route dies, Kelp will by default display a short error message. Set this
attribute to a true value, if you need to see a full stack trace of the error.
The `KELP_LONG_ERROR` environment variable can also set this attribute.

## req

This attribute only makes sense if called within a route definition. It will
contain a reference to the current [Kelp::Request](https://metacpan.org/pod/Kelp::Request) instance.

```perl
sub some_route {
    my $self = shift;
    if ( $self->req->is_json ) {
        ...
    }
}
```

## res

This attribute only makes sense if called within a route definition. It will
contain a reference to the current [Kelp::Response](https://metacpan.org/pod/Kelp::Response) instance.

```perl
sub some_route {
    my $self = shift;
    $self->res->json->render( { success => 1 } );
}
```

# METHODS

## build

On it's own the `build` method doesn't do anything. It is called by the
constructor, so it can be overridden to add route destinations and
initializations.

```perl
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
```

## load\_module

`load_module($name, %options)`

Used to load a module. All modules must be under the `Kelp::Module::`
namespace.

```perl
$self->load_module("Redis", server => '127.0.0.1');
# Will look for and load Kelp::Module::Redis
```

Options for the module may be specified after its name, or in the
`modules_init` hash in the config. The precedence is given to the
inline options.
See [Kelp::Module](https://metacpan.org/pod/Kelp::Module) for more information on making and using modules.

## build\_request

This method is used to create the request object for each HTTP request. It
returns an instance of [Kelp::Request](https://metacpan.org/pod/Kelp::Request), initialized with the current request's
environment. You can override this method to use a custom request module.

```perl
package MyApp;
use MyApp::Request;

sub build_request {
    my ( $self, $env ) = @_;
    return MyApp::Request->new( app => $app, env => $env );
}

# Now each request will be handled by MyApp::Request
```

## before\_finalize

Override this method, to modify the response object just before it gets
finalized.

```perl
package MyApp;

sub before_finalize {
    my $self = shift;
    $self->res->set_header("X-App-Name", "MyApp");
}

...
```

The above is an example of how to insert a custom header into the response of
every route.

## build\_response

This method creates the response object, e.g. what an HTTP request will return.
By default the object created is [Kelp::Response](https://metacpan.org/pod/Kelp::Response). Much like ["build\_request"](#build_request), the
response can also be overridden to use a custom response object.

## run

This method builds and returns the PSGI app. You can override it in order to
include middleware. See ["Adding middleware"](#adding-middleware) for an example.

## param

A shortcut to `$self->req->param`:

```perl
sub some_route {
    my $self = shift;
    if ( $self->param('age') > 18 ) {
        $self->can_watch_south_path(1);
    }
}
```

See [Kelp::Request](https://metacpan.org/pod/Kelp::Request) for more information and examples.

## session

A shortcut to `$self->req->session`. Take a look at ["session" in Kelp::Request](https://metacpan.org/pod/Kelp::Request#session)
for more information and examples.

## stash

Provides safe access to `$self->req->stash`. When called without
arguments, it will return the stash hash. If called with a single argument, it
will return the value of the corresponding key in the stash.
See ["stash" in Kelp::Request](https://metacpan.org/pod/Kelp::Request#stash) for more information and examples.

## named

Provides safe access to `$self->req->named`. When called without
arguments, it will return the named hash. If called with a single argument, it
will return the value of the corresponding key in the named hash.
See ["named" in Kelp::Request](https://metacpan.org/pod/Kelp::Request#named) for more information and examples.

## url\_for

A safe shortcut to `$self->routes->url`. Builds a URL from path and
arguments.

```perl
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
```

# SUPPORT

- GitHub: https://github.com/naturalist/kelp
- Mailing list: https://groups.google.com/forum/?fromgroups#!forum/perl-kelp

# AUTHOR

Stefan Geneshky - minimal <at> cpan.org

# CONTRIBUTORS

Ruslan Zakirov

Julio Fraire

Maurice Aubrey

David Steinbrunner

Gurunandan Bhat

# LICENSE

This module and all the modules in this package are governed by the same license
as Perl itself.
