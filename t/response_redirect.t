use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More tests => 8;

my $app = Kelp->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

$app->add_route( '/test' => sub { shift->res->redirect_to('/example') });
$t->request( GET '/test' )
    ->header_is('Location', '/example')
    ->code_is(302);

$app->add_route( '/catalogue/:id' => { to => 'test_catalogue', name => 'catalogue', defaults => { id => 'all' }});
$app->add_route( '/test2' => sub { shift->res->redirect_to('catalogue') });
$t->request( GET '/test2' )
    ->header_is('Location', '/catalogue/all')
    ->code_is(302);

$app->add_route( '/test3' => sub { shift->res->redirect_to('catalogue', {id => 243}) });
$t->request( GET '/test3' )
    ->header_is('Location', '/catalogue/243')
    ->code_is(302);

$app->add_route( '/test4' => sub { shift->res->redirect_to('catalogue', {}, 403) });
$t->request( GET '/test4' )
    ->header_is('Location', '/catalogue/all')
    ->code_is(403);

done_testing;
