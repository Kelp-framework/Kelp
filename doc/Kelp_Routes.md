# NAME

Kelp::Routes - Routing for a Kelp app

# SYNOPSIS

    my $r = Kelp::Routes->new( base => 'MyApp' );

    # Simple
    $r->add( '/home', 'home' );

    # With method
    $r->add( [ POST => '/item' ], 'items#add' );

    # Captures
    $r->add( '/user/:id',     'user#view' );       # Required
    $r->add( '/pages/?id',    'pages#view' );      # Optional
    $r->add( '/*article/:id', 'articles#view' );   # Wildcard

    # Extended options
    $r->add(
        '/resource/:id' => {
            via   => 'GET',               # match only GET
            to    => 'resources#view',    # send to MyApp::Resources::View
            check => { id => '\d+' },     # match only id =~ /\d+/
            name  => 'resource'           # name this route 'resource'
        }
    );

    # URL building
    say $r->url( 'resource', id => 100 );    # '/resource/100'

    # Bridges
    $r->add(
        '/users', {
            to     => 'users#auth',
            bridge => 1
        }
    );
    $r->add( '/users/edit' => 'user#edit' );
    # Will go through the bridge code first

    # Nested routes and bridges
    $r->add(
        '/users' => {
            to   => 'users#auth',
            tree => [
                '/home' => 'users#home',
                [ POST => '/edit' ] => 'users#edit',
                '/prefs' => {
                    to   => 'users#prefs',
                    tree => [
                        '/email' => 'users#prefs#email',
                        '/login' => 'users#prefs#login'
                    ]
                }
            ]
        }
    );

# DESCRIPTION

Routing is at the core of each web application. It provides the connection
between each HTTP request and the code.

Kelp provides a simple, yet sophisticated router. It utilizes Perl 5.10's
regular expressions, whish makes it fast, robust and reliable.

The routing process can roughly be broken down into three steps:

__1\. Adding routes__

First you create a router object:

    my $r = Kelp::Routers->new();

Then you add your application's routes and their descriptions:

    $r->add( '/path' => 'Module::function' );
    ...

__2\. Matching__

Once you have your routes added, you can match with the ["match"](#match) subroutine.

    $r->match( $path, $method );

The Kelp framework already does matching for you, so you may never
have to do your own matching. The above example is provided only for
reference.

__3\. Building URLs from routes__

You can name each of your routes and use that later to build a URL:

    $r->add( '/begin' => { to => 'function', name => 'home' } );
    my $url = $r->url('home');    # /begin

This can be used in views and other places where you need the full URL of
a route.

# PLACEHOLDERS

Each route is matched via a regular expression. You can write your own regular
expressions or you can use Kelp's _placeholders_. Placeholders are variables
you place in the route path. They are identified by a prefix character and
their names must abide to the rules of a regular perl variable. If necessary,
curly braces can be used to separate placeholders from the rest of the path.

There are three types of place holders: explicit, optional and wildcards.

## Explicit

These placeholders begin with a column (`:`) and must have a value in order for the
route to match. All characters are matched, except for the forward slash.

    $r->add( '/user/:id' => 'module#sub' );
    # /user/a       -> match (id = 'a')
    # /user/123     -> match (id = 123)
    # /user/        -> no match
    # /user         -> no match
    # /user/10/foo  -> no match

    $r->add( '/page/:page/line/:line' => 'module#sub' );
    # /page/1/line/2        -> match (page = 1, line = 2)
    # /page/bar/line/foo    -> match (page = 'bar', line = 'foo')
    # /page/line/4          -> no match
    # /page/5               -> no match

    $r->add( '/{:a}ing/{:b}ing' => 'module#sub' );
    # /walking/singing      -> match (a = 'walk', b = 'sing')
    # /cooking/ing          -> no match
    # /ing/ing              -> no match

## Optional

Optional placeholders begin with a question mark `?` and denote an optional
value. You may also specify a default value for the optional placeholder via
the ["defaults"](#defaults) option. Again, like the explicit placeholders, the optional
ones capture all characters, except the forward slash.

    $r->add( '/data/?id' => 'module#sub' );
    # /bar/foo          -> match ( id = 'foo' )
    # /bar/             -> match ( id = undef )
    # /bar              -> match ( id = undef )

    $r->add( '/:a/?b/:c' => 'module#sub' );
    # /bar/foo/baz      -> match ( a = 'bar', b = 'foo', c = 'baz' )
    # /bar/foo          -> match ( a = 'bar', b = undef, c = 'foo' )
    # /bar              -> no match
    # /bar/foo/baz/moo  -> no match

Optional default values may be specified via the `defaults` option.

    $r->add(
        '/user/?name' => {
            to       => 'module#sub',
            defaults => { name => 'hank' }
        }
    );

    # /user             -> match ( name = 'hank' )
    # /user/            -> match ( name = 'hank' )
    # /user/jane        -> match ( name = 'jane' )
    # /user/jane/cho    -> no match

## Wildcards

The wildcard placeholders expect a value and capture all characters, including
the forward slash.

    $r->add( '/:a/*b/:c'  => 'module#sub' );
    # /bar/foo/baz/bat  -> match ( a = 'bar', b = 'foo/baz', c = 'bat' )
    # /bar/bat          -> no match

## Using curly braces

Curly braces may be used to separate the placeholders from the rest of the
path:

    $r->add( '/{:a}ing/{:b}ing' => 'module#sub' );
    # /looking/seeing       -> match ( a = 'look', b = 'see' )
    # /ing/ing              -> no match

    $r->add( '/:a/{?b}ing' => 'module#sub' );
    # /bar/hopping          -> match ( a = 'bar', b = 'hopp' )
    # /bar/ing              -> match ( a = 'bar' )
    # /bar                  -> no match

    $r->add( '/:a/{*b}ing/:c' => 'module#sub' );
    # /bar/hop/ping/foo     -> match ( a = 'bar', b = 'hop/p', c = 'foo' )
    # /bar/ing/foo          -> no match

# BRIDGES

The ["match"](#match) subroutine will stop and return the route that best matches the
specified path. If that route is marked as a bridge, then ["match"](#match) will
continue looking for a match and will eventually return an array of one or
more routes. Bridges can be used for authentication or other route
preprocessing.

    $r->add( '/users', { to => 'Users::auth', bridge => 1 } );
    $r->add( '/users/:action' => 'Users::dispatch' );

The above example will require `/users/profile` to go through two
controllers: `Users::auth` and `Users::dispatch`:

    my $arr = $r->match('/users/view');
    # $arr is an array of two routes now, the bridge and the last one matched

# TREES

A quick way to add bridges is to use the ["tree"](#tree) option. It allows you to
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

The above call to `add` causes the following to occur under the hood:

- The paths of all routes inside the tree are joined to the path of their
parent, so the following five new routes are created:

        /users                  -> MyApp::Users::auth
        /users/profile          -> MyApp::Users::profile
        /users/settings         -> MyApp::Users::settings
        /users/settings/email   -> MyApp::Users::email
        /users/settings/login   -> MyApp::Users::login
- The names of the routes are joined with `_` to the name of their parent:

        /users                  -> 'users'
        /users/profile          -> 'users_profile'
        /users/settings         -> 'users_settings'
        /users/settings/email   -> 'users_settings_email'
        /users/settings/login   -> 'users_settings_login'
- The `/users` and `/users/settings` routes are automatically marked as
bridges, because they contain a tree.

# ATTRIBUTES

## base

Sets the base class for the routes destinations.

    my $r = Kelp::Routes->new( base => 'MyApp' );

This will prepend `MyApp::` to all route destinations.

    $r->add( '/home' => 'home' );          # /home -> MyApp::home
    $r->add( '/user' => 'user#home' );     # /user -> MyApp::User::home
    $r->add( '/view' => 'User::view' );    # /view -> MyApp::User::view

By default this value is an empty string and it will not prepend anything.
However, if it is set, then it will always be used. If you need to use
a route located in another package, you'll have to wrap it in a local sub:

    # Problem:

    $r->add( '/outside' => 'Outside::Module::route' );
    # /outside -> MyApp::Outside::Module::route
    # (most likely not what you want)

    # Solution:

    $r->add( '/outside' => 'outside' );
    ...
    sub outside {
        return Outside::Module::route;
    }

# SUBROUTINES

## add

Adds a new route definition to the routes array.

    $r->add( $path, $destination );

`$path` can be a path string, e.g. `'/user/view'` or an ARRAY containing a
method and a path, e.g. `[ PUT => '/item' ]`.

`$destination` can be a destination string, e.g. `'Users::item'`, a hash
containing more options or a CODE reference:

    my $r = Kelp::Routes->new( base => 'MyApp' );

    # /home -> MyApp::User::home
    $r->add( '/home' => 'user#home' );

    # GET /item/100 -> MyApp::Items::view
    $r->add(
        '/item/:id', {
            to  => 'items#view',
            via => 'GET'
        }
    );

    # /system -> CODE
    $r->add( '/system' => sub { return \%ENV } );

### Destination Options

#### to

Sets the destination for the route. It should be a subroutine name or CODE
reference. It could also be a shortcut, in which case it will get properly
camelized.

    $r->add( '/user' => 'users#home' );       # /home -> MyApp::Users::home
    $r->add( '/sys'  => sub { ... } );        # /sys -> execute code
    $r->add( '/item' => 'Items::handle' );    # /item -> MyApp::Items::handle
    $r->add( '/item' => { to => 'Items::handle' } );    # Same as above

#### via

Specifies an HTTP method to be considered by ["match"](#match) when matching a route.

    # POST /item -> MyApp::Items::add
    $r->add(
        '/item' => {
            via => 'POST',
            to  => 'items#add'
        }
    );

The above can be shortened with like this:

    $r->add( [ POST => '/item' ] => 'items#add' );

#### name

Give the route a name, that can be used to build a url later via the ["url"](#url)
subroutine.

    $r->add(
        '/item/:id/:name' => {
            to   => 'items#view',
            name => 'item'
        }
    );

    # Later
    $r->url( 'item', id => 8, name => 'foo' );    # /item/8/foo

#### check

A hashref of checks to perform on the captures. It should contain capture
names and stringified regular expressions. Do not use `^` and `$` to denote
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

#### defaults

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

#### bridge

If set to one this route will be treated as a bridge. Please see ["bridges"](#bridges)
for more information.

#### tree

Creates a tree of sub-routes. See ["trees"](#trees) for more information and examples.

## match

Returns an array of [Kelp::Routes::Pattern](http://search.cpan.org/perldoc?Kelp::Routes::Pattern) objects that match the path
and HTTP method provided. Each object will contain a hash with the named
placeholders in ["named" in Kelp::Routes::Pattern](http://search.cpan.org/perldoc?Kelp::Routes::Pattern#named), and an array with their
values in the order they were specified in the pattern in
["param" in Kelp::Routes::Pattern](http://search.cpan.org/perldoc?Kelp::Routes::Pattern#param).

    $r->add( '/:id/:name', "route" );
    for my $pattern ( @{ $r->match('/15/alex') } ) {
        $pattern->named;    # { id => 15, name => 'alex' }
        $pattern->param;    # [ 15, 'alex' ]
    }

Routes that used regular expressions instead of patterns will only initialize
the `param` array with the regex captures, unless those patterns are using
named captures in which case the `named` hash will also be initialized.

# SEE ALSO

[Kelp](http://search.cpan.org/perldoc?Kelp), [Routes::Tiny](http://search.cpan.org/perldoc?Routes::Tiny), [Forward::Routes](http://search.cpan.org/perldoc?Forward::Routes)

# CREDITS

Author: minimalist - minimal@cpan.org

# ACKNOWLEDGEMENTS

This module was inspired by [Routes::Tiny](http://search.cpan.org/perldoc?Routes::Tiny).

The concept of bridges was borrowed from [Mojolicious](http://search.cpan.org/perldoc?Mojolicious)

# LICENSE

Same as Perl itself.
