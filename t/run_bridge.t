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

