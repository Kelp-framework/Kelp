use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

my $app = Kelp->new( mode => 'test' );
$app->routes->base("main");
my $t = Kelp::Test->new( app => $app );

# Need only one route
$app->add_route( '/mw', sub { "OK" } );

$t->request( GET '/mw' )
  ->header_is("X-Framework", "Perl Kelp");

# Hack the config to insert middleware
$app->config_hash->{middleware} = ['XFramework'];
$app->config_hash->{middleware_init}->{XFramework} = {
    framework => 'Changed'
};

$t->request(GET '/mw')
  ->header_is("X-Framework", "Changed")
  ->header_isnt("Content-Length", 2);

# One more middleware
$app->{_loaded_middleware} = {};
$app->config_hash->{middleware} = ['XFramework', 'ContentLength'];
$t->request(GET '/mw')
  ->header_is("X-Framework", "Changed")
  ->header_is("Content-Length", 2);


done_testing;
