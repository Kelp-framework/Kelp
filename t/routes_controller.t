use lib 't/lib';
use Kelp::Base -strict;
use MyApp2;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

# Get the app
my $app = MyApp2->new(
    __config => {
        modules_init => {
            Routes => {
                base   => 'MyApp2::Controller',
                router => 'Controller',
            }
        }
    }
);

$app->routes->add('/inline', sub {"OK"});

# Test object
my $t = Kelp::Test->new( app => $app );

$t->request_ok( GET '/inline')
  ->content_is("OK");

$t->request_ok( GET '/blessed' )
  ->content_is('MyApp2::Controller');

$t->request_ok( GET '/blessed_bar' )
  ->content_is('MyApp2::Controller::Bar');

$t->request_ok( GET '/blessed_bar2' )
  ->content_is('MyApp2::Controller::Bar');

$t->request_ok( GET '/test_inherit' )
  ->content_is('OK');

$t->request_ok( GET '/test_module' )
  ->content_is('UTF-8');

done_testing;

