package Kelp::Test;

use Kelp::Base;
use Plack::Test;
use Plack::Util;
use Test::More import => ['!note'];
use Test::Deep;
use Kelp::Test::CookieJar;
use Carp;
use Try::Tiny;
use Kelp::Util;

BEGIN {
    $ENV{KELP_TESTING} = 1;    # Set the ENV for testing
}

sub import
{
    my ($me, @args) = @_;

    if ($args[0] && $args[0] eq -utf8) {
        my $builder = Test::More->builder;
        binmode $builder->output, ":encoding(utf8)";
        binmode $builder->failure_output, ":encoding(utf8)";
        binmode $builder->todo_output, ":encoding(utf8)";
    }
}

attr -psgi => undef;

attr -app => sub {
    my $self = shift;
    return defined $self->psgi
        ? Plack::Util::load_psgi($self->psgi)
        : die "'app' or 'psgi' parameter is required";
};
attr charset => undef;

attr res => sub { die "res is not initialized" };

attr cookies => sub { Kelp::Test::CookieJar->new };

sub _decode
{
    my ($self, $string) = @_;
    return Kelp::Util::charset_decode($self->charset // $self->app->charset, $string);
}

sub request
{
    my ($self, $req) = @_;
    croak "HTTP::Request object needed" unless ref($req) eq 'HTTP::Request';
    $self->note($req->method . ' ' . $req->uri);

    # Most likely the request was not initialized with a URI that had a scheme,
    # so we add a default http to prevent unitialized regex matches further
    # down the chain
    $req->uri->scheme('http') unless $req->uri->scheme;

    # If no host was given to the request's uri (most likely), then add
    # localhost. This is needed by the cookies header, which will not be
    # applied unless the request uri has a proper domain.
    if ($req->uri->opaque =~ qr|^/{1}|) {
        $req->uri->opaque('//localhost' . $req->uri->opaque);
    }

    # Add the current cookie to the request headers
    $self->cookies->add_cookie_header($req);

    my $res = test_psgi($self->app->run, sub { shift->($req) });

    # Extract the cookies from the response and add them to the cookie jar
    $self->cookies->extract_cookies($res);

    $self->res($res);
    return $self;
}

sub request_ok
{
    my ($self, $req, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->request($req)->code_is(200, $test_name);
}

sub code_is
{
    my ($self, $code, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Response code is $code";
    is $self->res->code, $code, $test_name;

    # If we got 500 back and shouldn't have, we show the content
    if ($code != 500 && $self->res->code == 500) {
        fail $self->res->content;
    }

    return $self;
}

sub code_isnt
{
    my ($self, $code, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Response code is not $code";
    isnt $self->res->code, $code, $test_name;
    return $self;
}

sub content_is
{
    my ($self, $value, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Content is '$value'";
    is $self->_decode($self->res->content), $value,
        $test_name;
    return $self;
}

sub content_bytes_are
{
    my ($self, $value, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Content is '$value'";
    my $got = unpack 'H*', $self->res->content;
    my $expected = unpack 'H*', $value;
    is $got, $expected, $test_name;
    return $self;
}

sub content_isnt
{
    my ($self, $value, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Content is not '$value'";
    isnt $self->_decode($self->res->content), $value,
        $test_name;
    return $self;
}

sub content_like
{
    my ($self, $regexp, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Content matches $regexp";
    like $self->_decode($self->res->content), $regexp,
        $test_name;
    return $self;
}

sub content_unlike
{
    my ($self, $regexp, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Content does not match $regexp";
    unlike $self->_decode($self->res->content), $regexp,
        $test_name;
    return $self;
}

sub content_type_is
{
    my ($self, $value, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Content-Type is '$value'";
    is $self->res->content_type, $value, $test_name;
    return $self;
}

sub full_content_type_is
{
    my ($self, $value, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Full Content-Type is '$value'";
    is join('; ', $self->res->content_type), $value, $test_name;
    return $self;
}

sub content_type_isnt
{
    my ($self, $value, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Content-Type is not '$value'";
    isnt $self->res->content_type, $value, $test_name;
    return $self;
}

sub header_is
{
    my ($self, $header, $value, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Header '$header' => '$value'";
    is $self->res->header($header), $value, $test_name
        || $self->diag_headers();
    return $self;
}

sub header_isnt
{
    my ($self, $header, $value, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Header '$header' is not '$value'";
    isnt $self->res->header($header), $value, $test_name
        || $self->diag_headers();
    return $self;
}

sub header_like
{
    my ($self, $header, $regexp, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Header '$header' =~ $regexp";
    like $self->res->header($header), $regexp, $test_name
        || $self->diag_headers();
    return $self;
}

sub header_unlike
{
    my ($self, $header, $regexp, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "Header '$header' !~ $regexp";
    unlike $self->res->header($header), $regexp, $test_name
        || $self->diag_headers();
    return $self;
}

sub json_content
{
    my $self = shift;
    my $result;
    my $decoder = $self->app->get_encoder(json => 'internal');
    try {
        $result = $decoder->decode(
            $self->_decode($self->res->content)
        );
    }
    catch {
        fail("Poorly formatted JSON");
    };
    return $result;
}

sub json_cmp
{
    my ($self, $expected, $test_name) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $test_name ||= "JSON structure matches";
    like $self->res->header('content-type'), qr/json/, 'Content-Type is JSON'
        or return $self;
    my $json = $self->json_content;
    cmp_deeply($json, $expected, $test_name) or diag explain $json;
    return $self;
}

sub note
{
    my $self = shift;
    Test::More::note @_;
    return $self;
}

sub diag_headers
{
    my $self = shift;
    diag $self->res->headers->as_string;
    return $self;
}

sub diag_content
{
    my $self = shift;
    diag $self->res->content;
    return $self;
}

1;

__END__

=pod

=head1 NAME

Kelp::Test - Automated tests for a Kelp web app

=head1 SYNOPSIS

    use MyApp;
    use Kelp::Test;
    use HTTP::Request::Common;

    my $app = MyApp->new;
    my $t = Kelp::Test->new( app => $app );

    $t->request( GET '/path' )
      ->code_is(200)
      ->content_is("It works");

    $t->request( POST '/api' )
      ->json_cmp({auth => 1});

    # automatically sets wide output for Test::More (disables Wide character warnings)
    use Kelp::Test -utf8;

=head1 DESCRIPTION

This module provides basic tools for testing a Kelp based web application. It
is object oriented, and all methods return C<$self>, so they can be chained
together.
Testing is done by sending HTTP requests to an already built application and
analyzing the response. Therefore, each test usually begins with the L</request>
method, which takes a single L<HTTP::Request> parameter. It sends the request to
the web app and saves the response as an L<HTTP::Response> object.

=head1 ENV VARIABLES

=head2 KELP_TESTING

This module sets the C<KELP_TESTING> environmental variable to a true value.

=head1 ATTRIBUTES

=head2 app

The Kelp::Test object is instantiated with single attribute called C<app>. It
is a reference to a Kelp based web app.

    my $myapp = MyApp->new;
    my $t = Kelp::Test->new( app => $myapp );

From this point on, all requests run with C<$t-E<gt>request> will be sent to C<$app>.

=head2 charset

The charset to use for decoding the response. By default, application's charset
will be used. Use it if some responses are in a different charset. Can be
cleared by setting it back to undef.

=head2 res

Each time C<$t-E<gt>request> is used to send a request, an HTTP::Response object is
returned and saved in the C<res> attribute. You can use it to run tests,
although as you will see, this module provides methods which make this a lot
easier. It is recommended that you use the convenience methods rather than using
C<res>.

    $t->request( GET '/path' )
    is $t->res->code, 200, "It's a success";

=head2 cookies

An object of C<Kelp::Test::CookieJar> implementing the partial interface of
L<HTTP::Cookies> module, containing the cookie jar for all tests. Compared to
the module it's mocking, it does not handle cookie parameters other than name
and value, but properly escapes the cookie name and value for the request.
Its usage should usually be as trivial as this:

    # NOTE: extra undef parameters are required to match HTTP::Cookies interface

    $t->set_cookie(undef, $name, $value);
    $t->request(...);

    my $cookies_hash = $t->get_cookies;
    my @cookie_values = $t->get_cookies(undef, 'cookie1', 'cookie2');

=head1 METHODS

=head2 request

C<request( $http_request )>

Takes an L<HTTP::Request> object and sends it to the application. When the
L<HTTP::Response> object is returned, it is initialized in the L</res>
attribute.
It is very convenient to use L<HTTP::Request::Common> in your test modules, so
you can take advantage of the simplified syntax for creating an HTTP request.

    $t->request( POST '/api', [ user => 'jane' ] );

This method returns C<$self>, so other methods can be chained after it.

=head2 request_ok

C<request_ok( $http_request, $test_name )>

Runs C<request>, then tests if the response code is 200. Equivalent to the following
code:

    $t->request( GET '/path' )->code_is(200);
    $t->request_ok( GET '/path' );    # Same as the above

=head2 code_is, code_isnt

C<code_is( $code, $test_name )>, C<code_isnt( $code, $test_name )>

Tests if the last response returned a status code equal or not equal to C<$code>.
An optional name of the test can be added as a second parameter.

    $t->request( GET '/path' )->code_is(200);
    $t->request( GET '/path' )->code_isnt(500);

=head2 request_ok

Same as L</request>, but also runs C<code_is(200)>.

    $t->request_ok( GET '/home' );
    # Tests for code = 200

=head2 content_is, content_isnt

C<content_is( $value, $test_name )>, C<content_isnt( $value, $test_name )>

Tests if the last response returned content equal or not equal to C<$value>.
An optional name of the test can be added as a second parameter.

    $t->request( GET '/path' )->content_is("Ok.");
    $t->request( GET '/path' )->content_isnt("Fail.");

=head2 content_bytes_are

Same as C<content_is>, but the result is not decoded and the values are
compared byte by byte as hex-encoded string.

=head2 content_like, content_unlike

C<content_like( $regexp, $test_name )>, C<content_unlike( $regexp, $test_name )>

Tests if the last response returned content that matches or doesn't match C<$regexp>.
An optional name of the test can be added as a second parameter.

    $t->request( GET '/path' )->content_like(qr{Amsterdam});
    $t->request( GET '/path' )->content_unlike(qr{Rotterdam});

=head2 content_type_is, content_type_isnt

C<content_type_is( $value, $test_name )>, C<content_type_isnt( $value, $test_name )>

Tests if the last response's content-type header is equal or not equal to C<$value>.
An optional name of the test can be added as a second parameter.

    $t->request( GET '/path' )->content_type_is("text/plain");
    $t->request( GET '/path' )->content_type_isnt("text/html");

=head2 full_content_type_is

Like L</content_type_is>, but checks the full content type (with charset).

=head2 header_is, header_isnt

C<header_is( $header, $value, $test_name )>, C<header_isnt( $header, $value, $test_name )>

Tests if the last response returned a header C<$header> that is equal or not
equal to C<$value>. An optional name of the test can be added as a second parameter.

    $t->request( GET '/path' )->header_is( "Pragma", "no-cache" );
    $t->request( GET '/path' )->header_isnt( "X-Check", "yes" );

=head2 header_like, header_unlike

C<header_like( $header, $regexp, $test_name )>, C<header_unlike( $header, $regexp, $test_name )>

Tests if the last response returned a header C<$header> that matches or doesn't
match C<$regexp>. An optional name of the test can be added as a second parameter.

    $t->request( GET '/path' )->header_like( "Content-Type", qr/json/ );
    $t->request( GET '/path' )->header_unlike( "Content-Type", qr/image/ );

=head2 json_content

C<json_content()>

Returns the content decoded as JSON. Does not perform any checks, but may
C<fail()> and return C<undef> if the JSON decoding fails.

=head2 json_cmp

C<json_cmp( $expected, $test_name )>

This tests for two things: If the returned C<content-type> is
C<application-json>, and if the returned JSON structure matches the structure
specified in C<$expected>. To compare the two structures this method uses
C<cmp_deeply> from L<Test::Deep>, so you can use all the goodies from the
C<SPECIAL-COMPARISONS-PROVIDED> section of the Test::Deep module.

    $t->request( GET '/api' )->json_cmp(
        {
            auth      => 1,
            timestamp => ignore(),
            info      => subhashof( { name => 'Rick James' } )
        }
    );

An optional name of the test can be added as a second parameter.

=head2 note

C<note( $note )>

Print a note, using the L<Test::More> C<note> function.

    $t->request( GET '/path' )
      ->note("Checking headers now")
      ->header_is( "Content-Type", qr/json/ );

=head2 diag_headers

Prints all headers for debugging purposes.

    $t->request( GET '/path' )
      ->header_is( "Content-Type", qr/json/ )
      ->diag_headers();

=head2 diag_content

Prints the entire content for debugging purposes.

    $t->request( GET '/path' )
      ->content_is("Well")
      ->diag_content();

=cut

