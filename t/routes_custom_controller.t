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
    ->content_is('CustomContext::Controller::Foo');

done_testing;

