use lib 't/lib';
use Kelp::Base -strict;
use MyApp3;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

# Get the app
my $app = MyApp3->new();

# Test object
my $t = Kelp::Test->new(app => $app);

$t->request_ok(GET '/a/b/c')
    ->content_type_is('text/plain')
    ->header_is('X-Final', 'CustomContext::Controller')
    ->content_is('CustomContext::Controller::Foo');

$t->request_ok(GET '/a/b/d')
    ->content_type_is('text/plain')
    ->header_is('X-Final', 'MyApp3')
    ->content_is('MyApp3');

$t->request_ok(GET '/a/b/e')
    ->content_type_is('text/plain')
    ->header_is('X-Final', 'CustomContext::Controller')
    ->content_is('PSGI OK');

# test template generated from response
$t->request_ok(GET '/b')
    ->content_like(qr{Hello, world!});

done_testing;

