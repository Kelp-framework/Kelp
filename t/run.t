use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

my $app = Kelp->new( mode => 'test' );
$app->routes->base("main");
my $t = Kelp::Test->new( app => $app );

# Nothing rendered
$app->add_route("/nothing", sub {});
$t->request( GET '/nothing' )->code_is(500);

# 404
$app->add_route("/not_found", sub {});
$t->request( GET '/not_found' )->code_is(500);

# Wrong route destination
$app->add_route("/wrong_to1", "missing");
$app->add_route("/wrong_to2", { to => [] });
$app->add_route("/wrong_to3", { to => {} });
$app->add_route("/wrong_to4", { to => undef });
$app->add_route("/wrong_to5", { to => 1 });
$app->add_route("/wrong_to6", { to => 'missing' });
for ( my $i = 1; $i <= 6; $i++ ) {
    $t->request( GET "/wrong_to$i" )->code_is(500)
}

# Named placeholders
$app->add_route("/named/:a", sub {
    my $self = shift;
    return "Got: " . $self->req->named->{a};
});
for my $a (qw{boo дума 123}) {
    $t->request( GET "/named/$a" )
      ->code_is(200)
      ->content_is("Got: $a");
}

# Array of placeholders
$app->add_route("/array/:a/:b", sub {
    my ($self, $a, $b) = @_;
    return "Got: $a and $b";
});
for my $a (qw{boo дума 123}) {
    $t->request( GET "/array/one/$a" )
      ->code_is(200)
      ->content_is("Got: one and $a");
}

# Param
$app->add_route("/param", sub {
    my $self = shift;
    return "We have " . $self->param('word');
});
for my $word ('word', 'дума', 'كلمة', 'բառ', 'sözcük') {
    $t->request( GET '/param?word=' . $word )
      ->code_is(200)
      ->content_like(qr{$word});
}

# Bridge
$app->add_route("/bridge" => {
    to => "bridge",
    tree => [
        "/route" => "bridge_route",
    ]
});
$t->request( GET '/bridge/route' )
  ->code_is(404);

$t->request( GET '/bridge/route?code=401' )
  ->code_is(401);

$t->request( GET '/bridge/route?ok=1' )
  ->code_is(200)
  ->content_is("We like milk.");

# Template
$app->add_route("/view", "view");
$t->request( GET '/view' )
  ->code_is(200)
  ->content_is("We are all living in America");

# Delayed
$app->add_route("/delayed", "delayed");
$t->request( GET '/delayed' )
  ->code_is(200)
  ->content_is("Better late than never.");

# Stash
$app->add_route("/auth" => {
    to => "auth",
    tree => [ "/work" => "work" ]
});
$t->request( GET '/auth/work' )
  ->code_is(200)
  ->content_is('foo');

# Methods
$app->add_route( [ POST => "/meth1" ] => sub { "OK" } );
$t->request( POST "/meth1" )->content_is("OK");
$app->add_route( [ GET => "/meth2" ] => sub { "OK" } );
$t->request( GET "/meth2" )->content_is("OK");
$app->add_route( [ PUT => "/meth3" ] => sub { "OK" } );
$t->request( PUT "/meth3" )->content_is("OK");

# Before render
$t->request( GET "/meth2" )->header_is('X-Framework', 'Perl Kelp');

done_testing;

sub bridge {
    my $self = shift;
    $self->req->stash->{info} = "We like milk.";
    if ( my $code = $self->param('code') ) {
        $self->res->code($code);
    }
    return $self->param('ok');
}

sub bridge_route {
    my $self = shift;
    return $self->req->stash->{info};
}

sub view {
    my $self = shift;
    $self->res->template(
        \"[% who %] are all living in [% where %]", {
            who   => 'We',
            where => 'America'
        }
    );
}

sub delayed {
    my $self = shift;
    return sub {
        my $responder = shift;
        $self->res->code(200);
        $self->res->text->body("Better late than never.");
        $responder->($self->res->finalize);
    };
}

sub auth {
    my $self = shift;
    $self->req->stash->{bar} = 'foo';
    return 1;
}

sub work {
    my $self = shift;
    return $self->req->stash->{bar};
}

