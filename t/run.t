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

# Route name
my $route_name_sub = sub {
    my $self = shift;
    return "Got: " . $self->req->route_name;
};

$app->add_route("/bridge", {
    name => 'named_bridge',
    to => sub { 1 },
    bridge => 1,
});

$app->add_route("/bridge/name", {
    name => 'named_route',
    to => $route_name_sub,
});

$app->add_route("/unnamed", $route_name_sub);

$t->request( GET "/bridge/name" )
  ->code_is(200)
  ->content_is("Got: named_route");

$t->request( GET "/unnamed" )
  ->code_is(200)
  ->content_is("Got: /unnamed");

# Route name - tree
$app->add_route("/tree", {
    name => 'tree_bridge',
    to => sub { 1 },
    tree => [
        "/name" => {
            name => 'tree_route',
            to => $route_name_sub,
        },
    ],
});

$t->request( GET "/tree/name" )
  ->code_is(200)
  ->content_is("Got: tree_bridge_tree_route");

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

# Manual render
$app->add_route(
    "/manual" => sub {
        my $self = shift;
        $self->res->render( { bar => 'foo' } );
        return { this => 'will not render' };
    }
);
$t->request( GET "/manual" )->json_cmp( { bar => 'foo' } );

done_testing;

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

