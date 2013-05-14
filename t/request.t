use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

my $app = Kelp->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

# is_json
$app->add_route('/json', sub {
    return $_[0]->req->is_json ? "ok" : "fail";
});
for my $ct (
    'application/json',
    'application/json; charset=UTF-8',
    'APPLICATION/json; charset=UTF-8',
    'APPLICATION/JSON; somethin=blah'
) {
    $t->request( GET '/json', Content_Type => $ct )
      ->code_is(200)
      ->content_is('ok');
}

# is_ajax
$app->add_route('/ajax', sub {
    return $_[0]->req->is_ajax ? "ok" : "fail";
});
$t->request( GET '/ajax', 'X-Requested-With' => 'XMLHttpRequest' )
  ->code_is(200)
  ->content_is('ok');

# param
$app->add_route('/param/:n', sub {
    my ( $self, $n ) = @_;
    if ($n == 1) {
        [ sort($self->param) ];
    }
    elsif ($n == 2) {
        my %h = map { $_ => $self->param($_) } $self->param;
        return \%h;
    }
    elsif ($n == 3) {
        return scalar($self->param);
    }
});
$t->request( POST '/param/1',
    'Content-Type' => 'application/json',
    'Content' => '{"a":"bar","b":"foo"}'
    )
  ->code_is(200)
  ->json_cmp(['a', 'b'], "Get JSON list of params");

$t->request( POST '/param/2',
    'Content-Type' => 'application/json',
    'Content' => '{"a":"bar","b":"foo"}'
    )
  ->code_is(200)
  ->json_cmp({a => "bar", b => "foo"}, "JSON array context");

$t->request( POST '/param/3',
    'Content-Type' => 'application/json',
    'Content' => '{"a":"bar","b":"foo"}'
    )
  ->code_is(200)
  ->json_cmp({a => "bar", b => "foo"}, "JSON scalar context");

$t->request( POST '/param/1', [a => "bar", b => "foo"])
  ->code_is(200)
  ->json_cmp(['a', 'b'], "Get POST list of params");

$t->request( POST '/param/2', [a => "bar", b => "foo"])
  ->code_is(200)
  ->json_cmp({a => "bar", b => "foo"}, "POST array context");

done_testing;
