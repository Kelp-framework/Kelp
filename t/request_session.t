use Kelp::Base -strict;
use Kelp::Test;
use Kelp;
use Test::More;
use HTTP::Request::Common;
use Plack::Middleware::Session;

my $app = Kelp->new(
    mode     => 'test',
    __config => { middleware => ['Session'] }
);
my $t = Kelp::Test->new( app => $app );

#ok $app->can('session');

$app->add_route( '/session', sub {
    my $r = $_[0]->req;
    my $s = $r->env->{'psgix.session'};
    is_deeply $r->session( bar => 'foo' ), { bar => 'foo' };
    is $r->session('bar'), 'foo';
    is $s->{'bar'}, 'foo';

    delete $r->session->{bar};
    is $r->session('bar'), undef;

    $r->session( bar => 'foo', baz => 'goo' );
    is $r->session('bar'), 'foo';
    is $r->session('baz'), 'goo';

    is $s->{'bar'}, 'foo';
    is $s->{'baz'}, 'goo';

    $r->session( faa => 'taa' );
    is_deeply $s, {
        bar => 'foo',
        baz => 'goo',
        faa => 'taa'
      };

    $r->session = {};
    is_deeply $r->session, $s;
});
$t->request( GET '/session' );

done_testing;
