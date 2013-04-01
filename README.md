# TITLE

Kelp - A web framework light, yet rich in nutrients.

# SYNOPSIS

File `MyWebApp.pm`:

```perl
package MyWebApp;
use base 'Kelp';

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

File `app.psgi`:

```perl
use MyWebApp;
my $app = MyWebApp->new;
$app->run;
```


Or, for quick prototyping use [Kelp::Less](http://search.cpan.org/perldoc?Kelp::Less):

```perl
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
maintain a healthy web app. It has tons of middleware, and several very well
tested high performance preforking servers, such as Starman.

Plack, however, is not a web framework, hence its creators have intentionally
omitted adding certain components. This is where Kelp gets to shine. It provides
a layer on top of Plack and puts everything together into a complete web
framework.

Kelp provides:

- __Advanced Routing__. Create intricate, yet simple ways to capture HTTP requests
and route them to their designated code. Use explicit and optional named
placeholders, wildcards, or just regular expressions.
- __Flexible Configuration__. Use different config for each environment, e.g.
development, deployment, etc. Merge a temporary configuration into your current
one for testing and debugging purposes.
- __Enhanced Logging__. Log messages at different levels of emergency. Log to a
file, screen, or anything supported by Log::Dispatcher.
- __Powerful Rendering__. Use the bult-in auto-rendering logic, or the template
module of your choice to return rich text, html and JSON responses.
- __JSON encoder/decoder__. If you're serious about your back-end code. Kelp comes
with JSON, but you can easily plug in JSON::XS or any decoder of your choice.
- __Extendable Core__. Kelp uses pluggable modules for everything. This allows
anyone to add a module for a custom interface. Writing Kelp modules is a
pleasant and fulfilling activity.
- __Sleek Testing__. Kelp takes Plack::Test and wraps it in an object oriented
class of convenience methods. Testing is done via sending requests to your
routes, then analyzing the response.

# WHY KELP?

What makes Kelp different from the other micro frameworks?
