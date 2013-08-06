use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

my $app = Kelp->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

# Bare render
$app->add_route( "/1", sub { $_[0]->res->render });
$t->request( GET "/1" )
    ->code_is(200)
    ->content_is('')
    ->content_type_is('text/html');

# Set code
$app->add_route( "/2", sub { $_[0]->res->set_code(401)->render });
$t->request( GET "/2" )->code_is(401);

# Set content type
$app->add_route( "/3", sub { $_[0]->res->html->render });
$t->request( GET "/3" )->content_type_is('text/html');

$app->add_route( "/4", sub { $_[0]->res->text->render });
$t->request( GET "/4" )->content_type_is('text/plain');

$app->add_route( "/5", sub { $_[0]->res->json->render({}) });
$t->request( GET "/5" )->content_type_is('application/json');

$app->add_route( "/51", sub { $_[0]->res->json->render("aaa") });
$t->request( GET "/51" )->code_is(500);

$app->add_route( "/52", sub { $_[0]->res->json->render(\"aaa") });
$t->request( GET "/52" )->code_is(500);

$app->add_route( "/53", sub { $_[0]->res->json->render([]) });
$t->request( GET "/53" )->code_is(200)->content_type_is('application/json');

$app->add_route( "/6", sub { $_[0]->res->xml->render });
$t->request( GET "/6" )->content_type_is('application/xml');

$app->add_route( "/7", sub { $_[0]->res->set_content_type('image/png')->render });
$t->request( GET "/7" )->content_type_is('image/png');

# Set header
$app->add_route( "/8", sub { $_[0]->res->set_header('x-something', 'foo')->render });
$t->request( GET "/8" )->header_is('x-something', 'foo');

# 404
$app->add_route( "/404", sub { $_[0]->res->render_404 });
$t->request( GET "/404" )->code_is(404);

# 500
$app->add_route( "/500", sub { $_[0]->res->render_500 });
$t->request( GET "/500" )->code_is(500);

# Redirect
$app->add_route( "/redi1", sub { $_[0]->res->redirect_to('/') });
$t->request( GET "/redi1" )->code_is(302);
$app->add_route( "/redi2", sub { $_[0]->res->redirect_to('/', {}, 301) });
$t->request( GET "/redi2" )->code_is(301);

# Die
$app->add_route( "/die", sub { die "You all suck." });
$t->request( GET "/die" )->code_is(500);

# Render
$app->add_route( "/r1", sub { return "Ahoi" });
$t->request( GET "/r1" )
    ->code_is(200)
    ->content_type_is('text/html')
    ->content_is("Ahoi");

$app->add_route( "/r2", sub { return { a => 'foo' } });
$t->request( GET "/r2" )
    ->code_is(200)
    ->content_type_is('application/json')
    ->json_cmp({ a => 'foo' });

# Template
$app->add_route( "/t1", sub { $_[0]->res->text->template( \"[% word %]", { word => 'duck' } ) } );
$t->request( GET "/t1" )
    ->code_is(200)
    ->content_type_is('text/plain')
    ->content_is("duck");

$app->add_route( "/t2", sub { $_[0]->res->html->template( \"[% word %]", { word => 'swan' } ) } );
$t->request( GET "/t2" )
    ->code_is(200)
    ->content_type_is('text/html')
    ->content_is("swan");

$app->add_route( "/bin1", sub { $_[0]->res->render_binary( "123" ) } );
$t->request( GET "/bin1" )->code_is(500);

$app->add_route( "/bin2", sub { $_[0]->res->set_content_type("image/png")->render_binary( "123" ) } );
$t->request( GET "/bin2" )->code_is(200);

done_testing;
