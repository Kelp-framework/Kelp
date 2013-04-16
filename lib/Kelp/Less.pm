package Kelp::Less;

use Kelp;
use Kelp::Base -strict;

our @EXPORT = qw/
  app
  attr
  route
  get
  post
  put
  del
  run
  param
  stash
  named
  req
  res
  template
  /;

our $app;

sub import {
    my $class  = shift;
    my $caller = caller;
    no strict 'refs';
    for my $sub (@EXPORT) {
        *{"${caller}::$sub"} = eval("\\\&$sub");
    }

    strict->import;
    warnings->import;
    feature->import(':5.10');

    $app = Kelp->new(@_);
    $app->routes->base('main');
}

sub route {
    my ( $path, $to ) = @_;
    $app->add_route( $path, $to );
}

sub get {
    my ( $path, $to ) = @_;
    route ref($path) ? $path : [ GET => $path ], $to;
}

sub post {
    my ( $path, $to ) = @_;
    route ref($path) ? $path : [ POST => $path ], $to;
}

sub put {
    my ( $path, $to ) = @_;
    route ref($path) ? $path : [ PUT => $path ], $to;
}

sub del {
    my ( $path, $to ) = @_;
    route ref($path) ? $path : [ DELETE => $path ], $to;
}

sub run {

    # If we're running a test, then return the entire app,
    # otherwise return the PSGI subroutine
    return $ENV{KELP_TESTING} ? $app : $app->run;
}

sub app      { $app }
sub attr     { Kelp::Base::attr( ref($app), @_ ) }
sub param    { $app->param(@_) }
sub stash    { $app->stash(@_) }
sub named    { $app->named(@_) }
sub req      { $app->req }
sub res      { $app->res }
sub template { $app->res->template(@_) }
sub debug    { $app->debug(@_) }
sub error    { $app->error(@_) }

1;

__END__

=pod

=head1 NAME

Kelp::Less - Quick prototyping with Kelp

=head1 SYNOPSIS

    use Kelp::Less;

    get '/person/:name' => sub {
        "Hello " . named 'name';
    };

    run;

=head1 DESCRIPTION

This class exists to provide a way for quick and sloppy prototyping of a web
application. It is a wrapper for L<Kelp>, which imports several keywords, making
it easier and less verbose to create a quick web app.

It's called C<Less>, because there is less typing involved, and
because it is suited for smaller, less complicated web projects. We encourage
you to use it anywhere you see fit, however for mid-size and big applications we
recommend that you use the fully structured L<Kelp>. This way you can take
advantage of its powerful router, initialization and testing capabilities.

=head1 QUICK START

Each web app begins with C<use Kelp::Less;>. This automatically imports C<strict>,
C<warnings>, C<v5.10> as well as several useful functions. You can pass any
parameters to the constructor at the C<use> statement:

    use Kelp::Less mode => 'development';

The above is equivalent to:

    use Kelp;
    my $app = Kelp->new( mode => 'development' );

After that, you could add any initializations and attributes. For example, connect
to a database or setup cache. C<Kelp::Less> exports L<attr|Kelp::Base/attr>,
so you can use it to register attributes to your app.

    # Connect to DBI and CHI right away
    attr dbh => sub {
        DBI->connect( @{ app->config('database') } );
    };

    attr cache => sub {
        CHI->new( @{ app->config('cache') } );
    };

    # Another lazy attribute.
    attr version => sub {
        app->dbh->selectrow_array("SELECT version FROM vars");
    };

    # Later:
    app->dbh->do(...);
    app->cache->get(...);
    if ( app->version ) { ... }

Now is a good time to add routes. Routes are added via the L</route> keyword and
they are automatically registered in your app. A route needs two parameters -
C<path> and C<destination>. These are exactly equivalent to L<Kelp::Routes/add>,
and you are encouraged to read its POD to get familiar with how to define routes.
Here are a few examples for the impatient:

    # Add a 'catch-all-methods' route and send it to an anonymous sub
    route '/hello/:name' => sub {
        return "Hello " . named('name');
    };

    # Add a POST route
    route [ POST => '/edit/:id' ] => sub {
        # Do something with named('id')
    };

    # Route that runs an existing sub in your code
    route '/login' => 'login';
    sub login {
        ...
    }

Each route subroutine receives C<$self> and all named placeholders.

    route '/:id/:page' => sub {
        my ( $self, $id, $page ) = @_;
    };

Here, C<$self> is the app object and it can be used the same way as in a full
L<Kelp> route. For the feeling of magic and eeriness, C<Kelp::Lite> aliases
C<app> to C<$self>, so the former can be used as a full substitute to the
latter. See the exported keywords section for more information.

After you have added all of your routes, it is time to run the app. This is done
via a single command:

    run;

It returns PSGI ready subroutine, so you can immediately deploy your new app via
Plack:

    > plackup myapp.psgi
    HTTP::Server::PSGI: Accepting connections at http://0:5000/

=head1 KEYWORDS

The following list of keywords are exported to allow for less typing in
C<Kelp::Less>:

=head2 app

This a full alias for C<$self>. It is the application object, and an
instance of the C<Kelp> class. You can use it for anything you would use
C<$self> inside a route.

    route '/die' => sub {
        app->res->code(500);
    };

=head2 attr

Assigns lazy or active attributes (using L<Kelp::Base>) to C<app>. Use it to
initialize your application.

    attr mongo => MongoDB::MongoClient->new( ... );

=head2 route

Adds a route to C<app>. It is an alias to C<$self-E<gt>routes-E<gt>add>, and requires
the exact same parameters. See L<Kelp::Routes> for reference.

    route '/get-it' => sub { "got it" };

=head2 get, post, put, del

These are shortcuts to C<route> restricted to the corresponding HTTP method.

    get '/data'  => sub { "Only works with GET" };
    post '/data' => sub { "Only works with POST" };
    put '/data'  => sub { "Only works with PUT" };
    del '/data'  => sub { "Only works with DELETE" };

=head2 param

An alias for C<$self-E<gt>param> that gets the GET or POST parameters.
When used with no arguments, it will return an array with the names of all http
parameters. Otherwise, it will return the value of the requested http parameter.

    get '/names' => sub {
        my @names = param;
        # Now @names contains the names of the params
    };

    get '/value' => sub {
        my $id = param 'id';
        # Now $is contains the value of 'id'
    };

=head2 stash

An alias for C<$self-E<gt>stash>. The stash is a concept originally conceived by the
developers of L<Catalyst>. It's a hash that you can use to pass data from one
route to another.

    # Create a bridge route that checks if the user is authenticated, and saves
    # the username in the stash.
    get '/user' => { bridge => 1, to => sub {
        return stash->{username} = app->authenticate();
    }};

    # This route is run after the above bridge, so we know that we have an
    # authenticated user and their username in the stash.
    get '/user/welcome' => sub {
        return "Hello " . stash 'username';
    };

With no arguments C<stash> returns the entire stash hash. A single argument is
interpreted as the key to the stash hash and its value is returned accordingly.

=head2 named

An alias for C<$self-E<gt>named>. The C<named> hash contains the names and values of
the named placeholders from the current route's path. Much like the C<stash>,
with no arguments it returns the entire C<named> hash, and with a single
argument it returns the value for the corresponding key in the hash.

    get '/:name/:id' => sub {
        my $name = named 'name';
        my $id = name 'id';
    };

In the above example a GET request to C</james/1000> will initialize C<$name>
with C<"james"> and C<$id> with C<1000>.

=head2 req

An alias for C<$self-E<gt>req>, this provides quick access to the
L<Kelp::Request> object for the current route.

    # Inside a route
    if ( req->is_ajax ) {
        ...
    }

=head2 res

An alias for C<$self-E<gt>res>, this is a shortcut for the L<Kelp::Response>
object for the current route.

    # Inside a route
    res->code(403);
    res->json->render({ message => "Forbidden" });

=head2 template

A shortcut to C<$self-E<gt>res-E<gt>template>. Renders a template using the
currently loaded template module.

    get '/hello/:name' => sub {
        template 'hello.tt', { name => named 'name' };
    };

=head2 run

Creates and returns a PSGI ready subroutine, and makes the app ready for C<Plack>.

=head1 TESTING

When writing a C<Kelp::Less> app, we don't have a separate class to initialize and
feed into a L<Kelp::Test> object, because all of our code is contained in the
C<app.psgi> file. In this case, the C<Kelp::Test> object can be initialized
with the name of the C<PSGI> file in the C<psgi> argument.

    # t/main.t
    use Kelp::Test;

    my $t = Kelp::Test->new( psgi => 'app.psgi' );
    # Do some tests ...

Since you don't have control over the creation of the C<Kelp> object, if you
need to specify a different mode for testing, you can use the C<PLACK_ENV>
environmental variable:

    > PLACK_ENV=test prove -l

This will enable the C<conf/test.pl> configuration, which you should
tailor to your testing needs.

=head1 ACKNOWLEDGEMENTS

This module's interface was inspired by L<Dancer>, which in its turn was
inspired by Sinatra, so Viva La Open Source!

=cut
