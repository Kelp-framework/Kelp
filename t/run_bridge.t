use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

my $app = Kelp->new( mode => 'test' );
$app->routes->base("main");
my $t = Kelp::Test->new( app => $app );

# Bridge
$app->add_route(
    "/bridge" => {
        to   => "bridge",
        tree => [ "/route" => "bridge_route" ]
    }
);
$t->request( GET '/bridge' )->code_is(401);
$t->request( GET '/bridge/route' )->code_is(401);
$t->request( GET '/bridge/route?code=404' )->code_is(404);

$t->request( GET '/bridge/route?ok=1' )
  ->code_is(200)
  ->content_is("We like milk.");

# render inside bridge
$app->add_route(
    "/render" => {
        to => sub {
            $_[0]->res->set_code(700)->render('auth');
        },
        bridge => 1
    }
);

$t->request( GET '/render' )
  ->code_is(700)
  ->content_is('auth');

# Redirect inside bridge
$app->add_route( '/auth' => sub { 'auth' } );
$app->add_route(
    '/redirect' => {
        to => sub { $_[0]->res->redirect_to('/auth'); 0 },
        tree => [
            '/dead' => sub { 'you should not see this' }
        ]
    }
);

$t->request( GET '/redirect/dead' )
  ->code_is(302)
  ->header_like(location => qr{/auth$});

done_testing;

sub bridge {
    my $self = shift;
    $self->req->stash->{info} = "We like milk.";
    if ( my $code = $self->param('code') ) {
        $self->res->set_code($code)->render("ok");
    }
    return $self->param('ok');
}

sub bridge_route {
    my $self = shift;
    return $self->req->stash->{info};
}
