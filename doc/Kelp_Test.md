# NAME

Kelp::Test - Automated tests for a Kelp web app

# SYNOPSIS

    use MyWebApp;
    use Kelp::Test;
    use HTTP::Request::Common;

    my $app = MyWebApp->new;
    my $t = Kelp::Test->new( app => $app );

    $t->request( GET '/path' )
      ->code_is(200)
      ->content_is("It works");

    $t->request( POST '/api' )
      ->json_cmp({auth => 1});

# DESCRIPTION

This module provides basic tools for testing a Kelp based web application. It
is object oriented, and all methods return `$self`, so they can be chained
togehter.
Testing is done by sending HTTP requests to an already built application and
analyzing the response. Therefore, each test usually begins with the ["request"](#request)
method, which takes a single [HTTP::Request](http://search.cpan.org/perldoc?HTTP::Request) parameter. It sends the request to
the web app and saves the response as an [HTTP::Response](http://search.cpan.org/perldoc?HTTP::Response) object.

# ATTRIBUTES

## app

The Kelp::Test object is instantiated with single attribute called `app`. It
is a reference to a Kelp based web app.

    my $myapp = MyWebApp->new;
    my $t = Kelp::Test->new( app => $myapp );

From this point on, all requests run with `$t-`request> will be sent to `$app`.

## res

Each time `$t-`request> is used to send a request, an HTTP::Response object is
returned and saved in the `res` attribute. You can use it to run tests,
although as you will see, this module provides methods which make this a lot
easier. It is recommended that you use the convenience methods rather than using
`res`.

    $t->request( GET '/path' )
    is $t->res->code, 200, "It's a success";

# METHODS

## request

`request( $http_request )`

Takes a [HTTP::Request](http://search.cpan.org/perldoc?HTTP::Request) object and sends it to the application. When a
[HTTP::Response](http://search.cpan.org/perldoc?HTTP::Response) object is returned, it is initialized in the ["res"](#res)
attribute.
It is very convenient to use [HTTP::Request::Common](http://search.cpan.org/perldoc?HTTP::Request::Common) in your test modules, so
you can take advantage of the simplified syntax for creating a HTTP request.

    $t->request( POST '/api', [ user => 'jane' ] );

This method returns `$self`, so other methods can be chained after it.

## code\_is

`code_is( $code, $test_name )`

Tests if the last response returned a status code equal to `$code`. An optional
name of the test can be added as a second parameter.

    $t->request( GET '/path' )->code_is(200);

If the returned code is 500 and another code was expected, this method will
`fail` with the contents of the response, showing the error message.

## content\_is

`content_is( $value, $test_name )`

Tests if the last response returned content equal to `$value`. An optional
name of the test can be added as a second parameter.

    $t->request( GET '/path' )->content_is("Ok.");

## content\_like

`content_like( $regexp, $test_name )`

Tests if the last response returned content that matches `$regexp`. An optional
name of the test can be added as a second parameter.

    $t->request( GET '/path' )->content_like(qr{Amsterdam});

## content\_type\_is

`content_type_is( $value, $test_name )`

Tests if the last response's content-type header is equeal to `$value`. An optional
name of the test can be added as a second parameter.

    $t->request( GET '/path' )->content_type_is("text/plain");

## header\_is

`header_is( $header, $value, $test_name )`

Tests if the last response returned a header `$header` that is equal to
`$value`. An optional name of the test can be added as a second parameter.

    $t->request( GET '/path' )->header_is( "Pragma", "no-cache" );

## header\_like

`header_like( $header, $regexp, $test_name )`

Tests if the last response returned a header `$header` that matches `$regexp`.
An optional name of the test can be added as a second parameter.

    $t->request( GET '/path' )->header_is( "Content-Type", qr/json/ );

## json\_cmp

`json_cmp( $expected, $test_name )`

This tests for two things: If the returned `content-type` is
`application-json`, and if the returned JSON structure matches the structure
specified in `$expected`. To compare the two structures this method uses
`cmp_deeply` from [Test::Deep](http://search.cpan.org/perldoc?Test::Deep), so you can use all the goodies from the
`SPECIAL-COMPARISONS-PROVIDED` section of the Test::Deep module.

    $t->request( GET '/api' )->json_cmp(
        {
            auth      => 1,
            timestamp => ignore(),
            info      => subhashof( { name => 'Rick James' } )
        }
    );

An optional name of the test can be added as a second parameter.

## note

`note( $note )`

Print a note, using the [Test::More](http://search.cpan.org/perldoc?Test::More) `note` function.

    $t->request( GET '/path' )
      ->note("Checking headers now")
      ->header_is( "Content-Type", qr/json/ );

## diag\_headers

Prints all headers for debugging purposes.

    $t->request( GET '/path' )
      ->header_is( "Content-Type", qr/json/ )
      ->diag_headers();

## diag\_content

Prints the entire content for debugging purposes.

    $t->request( GET '/path' )
      ->content_is("Well")
      ->diag_content();

# SEE ALSO

[Kelp](http://search.cpan.org/perldoc?Kelp)

# CREDITS

Author: minimalist - minimal@cpan.org

# LICENSE

Same as Perl itself.
