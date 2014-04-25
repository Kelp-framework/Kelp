use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

my $app = Kelp->new( mode => 'test', __config => 1 );
$app->routes->base("main");

# Need only one route
$app->add_route( '/mw', sub { "OK" } );

my $t = Kelp::Test->new( app => $app );

# No middleware
$t->request( GET '/mw' )
  ->header_is( "X-Framework", "Perl Kelp" );

# Add middleware
$app->_cfg->merge(
    {
        middleware      => [ 'XFramework', 'ContentLength' ],
        middleware_init => {
            XFramework => {
                framework => 'Changed'
            }
        }
    }
);

$t->request( GET '/mw' )
  ->header_is( "X-Framework", "Changed" )
  ->header_is( "Content-Length", 2 );

done_testing;
