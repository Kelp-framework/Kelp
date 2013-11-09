use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;
use FindBin '$Bin';

# Allow the redefining of globs at Kelp::Module
BEGIN {
    $ENV{KELP_REDEFINE} = 1;
    $ENV{KELP_CONFIG_DIR} = "$Bin/conf/null";
}

{
    my $t = app_t();

    $t->request( GET '/mw' )
      ->header_is("X-Framework", "Perl Kelp");
}

{
    $ENV{KELP_CONFIG_DIR} = "$Bin/conf/mw";
    my $t = app_t();

    for ( 0 .. 1 ) {
        $t->request( GET '/mw' )
          ->header_is( "X-Framework", "Changed" )
          ->header_is( "Content-Length", 2 );
    }
}

sub app_t {
    my $app = Kelp->new( mode => 'test' );
    $app->routes->base("main");
    my $t = Kelp::Test->new( app => $app );

    # Need only one route
    $app->add_route( '/mw', sub { "OK" } );

    return $t;
}

done_testing;
