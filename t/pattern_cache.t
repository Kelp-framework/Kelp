
use strict;
use warnings;
use v5.10;

use Test::More;
use Kelp;
use Kelp::Routes::Pattern;
use Kelp::Test;
use HTTP::Request::Common;

my $app = Kelp->new( mode => 'test', modules => ['JSON'] );
my $t = Kelp::Test->new( app => $app );

# param
$app->add_route(
    '/test/:a/:b',
    sub {
        my ( $self, $a, $b ) = @_;
        sprintf( '%s-%s-%s-%s', $a, $b, $self->named('a'), $self->named('b') );
    }
);

srand;
for (1..10) {
    my $a = int(rand(500));
    my $b = int(rand(500));
    $t->request( POST "/test/$a/$b" )->content_is("$a-$b-$a-$b");
}


$app->add_route( '/test2/:i', sub {
    $_[0]->param('b') . $_[1];
});

for ( 1 .. 10 ) {
    my $b = int( rand(500) );
    $t->request( POST "/test2/1",
        'Content-Type' => 'application/json',
        'Content' => sprintf('{"b":%i}', $b)
    )->content_is("${b}1");
    $t->request( POST "/test2/1", [ b => $b ] )->content_is("${b}1");
}

# param
$app->add_route('/test3/:n', sub {
    my ( $self, $n ) = @_;
    if ($n == 1) {
        [ sort($self->param) ];
    }
    elsif ($n == 2) {
        my %h = map { $_ => $self->param($_) } $self->param;
        return \%h;
    }
});
$t->request( POST '/test3/1',
    'Content-Type' => 'application/json',
    'Content' => '{"a":"bar","b":"foo"}'
    )
  ->code_is(200)
  ->json_cmp(['a', 'b'], "Get JSON list of params");

$t->request( POST '/test3/2',
    'Content-Type' => 'application/json',
    'Content' => '{"a":"bar","b":"foo"}'
    )
  ->code_is(200)
  ->json_cmp({a => "bar", b => "foo"}, "Get JSON struct of params");

$t->request( POST '/test3/1', [a => "bar", b => "foo"])
  ->code_is(200)
  ->json_cmp(['a', 'b'], "Get POST list of params");

$t->request( POST '/test3/2', [a => "bar", b => "foo"])
  ->code_is(200)
  ->json_cmp({a => "bar", b => "foo"}, "Get POST struct of params");


done_testing;
