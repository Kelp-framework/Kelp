use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;
use FindBin '$Bin';

BEGIN {
    $ENV{KELP_REDEFINE} = 1;
}

# Error templates present
{
    my $app = Kelp->new( mode => 'test' );
    my $r = $app->routes;
    my $t = Kelp::Test->new( app => $app );

    $r->add("/404", sub { $_[0]->res->render_404 });
    $t->request( GET "/404" )
      ->code_is(404)
      ->content_like(qr/Four Oh Four/, "Custom 404 template engaged");

    $r->add("/700", sub { $_[0]->res->render_error( 700, "Custom" ) });
    $t->request( GET '/700' )
      ->code_is(700)
      ->content_like(qr/Seven Hundred/, "Custom 700 template engaged")
      ->content_unlike(qr/Custom/);

    $r->add("/500", sub { $_[0]->res->render_500( $_[0]->param('m') ) });
    $t->request( GET '/500' )
      ->code_is(500)
      ->content_like(qr/Five Hundred/, "Custom 500 template engaged");
    $t->request( GET '/500?m=Foo' )
      ->code_is(500)
      ->content_unlike(qr/Five Hundred/, "Message trums default template in dev")
      ->content_like(qr/Foo/);
}

# No error templates
{
    $ENV{KELP_CONFIG_DIR} = "$Bin/conf/error";
    my $app = Kelp->new( mode => 'test' );
    my $r = $app->routes;
    my $t = Kelp::Test->new( app => $app );

    $r->add("/404", sub { $_[0]->res->render_404 });
    $t->request( GET "/404" )
      ->code_is(404)
      ->content_unlike(qr/Four Oh Four/, "Default 404 message engaged");

    $r->add("/700", sub { $_[0]->res->render_error( 700, "Custom" ) });
    $t->request( GET '/700' )
      ->code_is(700)
      ->content_unlike(qr/Seven Hundred/)
      ->content_like(qr/Custom/, "Default 700 message engaged");

    $r->add("/500", sub { $_[0]->res->render_500( $_[0]->param('m') ) });
    $t->request( GET '/500' )
      ->code_is(500)
      ->content_unlike(qr/Five Hundred/, "Default 500 template engaged");
    $t->request( GET '/500?m=Foo' )
      ->code_is(500)
      ->content_unlike(qr/Five Hundred/, "Default 500 template engaged")
      ->content_like(qr/Foo/);
}

# Deployment
{
    my $app = Kelp->new( mode => 'deployment' );
    my $r = $app->routes;
    my $t = Kelp::Test->new( app => $app );

    $r->add("/500", sub { $_[0]->res->render_500( $_[0]->req->param('m') ) });
    $t->request( GET '/500' )
      ->code_is(500)
      ->content_like(qr/Five Hundred/, "Custom 500 template engaged");
    $t->request( GET '/500?m=Foo' )
      ->code_is(500)
      ->content_like(qr/Five Hundred/, "Custom 500 template engaged")
      ->content_unlike(qr/Foo/);
}


done_testing;
