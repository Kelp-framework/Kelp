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

    $r->add("/exception_text", sub { die "Text exception"; });
    $t->request( GET '/exception_text' )
      ->code_is(500)
      ->content_like(qr/Text exception/);

    $r->add("/exception_obj", sub { die bless {}, 'Exception'; });
    $t->request( GET '/exception_obj' )
      ->code_is(500)
      ->content_like(qr/Exception/);
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

    $r->add("/500_json", sub { $_[0]->res->render_500({ json => 'error' }) });
    $t->request( GET '/500_json' )
        ->code_is(500)
        ->json_cmp({ json => 'error' });
    
    $r->add("/exception_text", sub { die "Text exception"; });
    $t->request( GET '/exception_text' )
      ->code_is(500)
      ->content_like(qr/Text exception/);
    
    $r->add("/exception_obj", sub { die bless {}, 'Exception'; });
    $t->request( GET '/exception_obj' )
      ->code_is(500)
      ->content_like(qr/Exception/);
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

    $r->add("/exception_text", sub { die bless {}, 'Exception'; });
    $t->request( GET '/exception_text' )
      ->code_is(500)
      ->content_like(qr/Five Hundred/);

    $r->add("/exception_obj", sub { die "Text exception"; });
    $t->request( GET '/exception_obj' )
      ->code_is(500)
      ->content_like(qr/Five Hundred/);
}

# StackTrace enabled
{
    local *STDERR;
    $ENV{KELP_CONFIG_DIR} = "$Bin/conf/stack_trace_enabled";
    my $app = Kelp->new( mode => 'test' );
    my $r   = $app->routes;
    my $t   = Kelp::Test->new( app => $app );

    # we must not catch template not found error when try to
    # render_500
    $r->add("/render_500", sub { $_[0]->res->render_500 });
    $t->request( GET '/render_500' )
      ->code_is(500)
      ->content_like(qr/500 - Internal Server Error/);

    # and json
    $r->add("/500_json", sub { $_[0]->res->render_500({ json => 'error' }) });
    $t->request( GET '/500_json' )
        ->code_is(500)
        ->json_cmp({ json => 'error' });

    # and render_error too
    $r->add("/render_error", sub { $_[0]->res->render_error });
    $t->request( GET '/render_error' )
      ->code_is(500)
      ->content_like(qr/500 - Internal Server Error/);
    
    # but if we get real exeptions middleware must catch it
    $r->add("/500", sub { die; });
    $t->request( GET '/500' )
      ->code_is(500)
      ->content_unlike(qr/500 - Internal Server Error/);
}

# Deployment no error templates
# Any unknown(500) error in deployment mode with out templates
# must show stock "Internal Server Error" message
{
    $ENV{KELP_CONFIG_DIR} = "$Bin/conf/deployment_no_templates";
    my $app = Kelp->new( mode => 'deployment' );
    my $r   = $app->routes;
    my $t   = Kelp::Test->new( app => $app );

    $r->add("/500", sub { $_[0]->res->render_500($_[0]->req->param('m')) });
    $t->request( GET '/500' )
      ->code_is(500)
      ->content_like(qr/500 - Internal Server Error/);
    $t->request( GET '/500?m=Foo' )
      ->code_is(500)
      ->content_like(qr/500 - Internal Server Error/);  

    $r->add("/500_json", sub { $_[0]->res->render_500({ json => 'error' }) });
    $t->request( GET '/500_json' )
      ->code_is(500)
      ->content_like(qr/500 - Internal Server Error/);

    $r->add("/render_error", sub { $_[0]->res->render_error });
    $t->request( GET '/render_error' )
      ->code_is(500)
      ->content_like(qr/500 - Internal Server Error/);  

    $r->add("/exception", sub { die bless {}, 'Exception'; });    
    $t->request( GET '/exception' )
      ->code_is(500)
      ->content_like(qr/500 - Internal Server Error/);
}

done_testing;
