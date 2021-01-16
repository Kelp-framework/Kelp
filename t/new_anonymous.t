use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;
use Test::Exception;
use Scalar::Util qw(blessed refaddr);

my ($app1, $app2);

lives_ok sub {
    $app1 = Kelp->new_anon( mode => 'test' );
    $app2 = Kelp->new_anon( mode => 'test' );
}, 'construction ok';

ok $app1, 'first anonymous app ok';
ok $app2, 'second anonymous app ok';

like blessed $app1, qr/^Kelp::Anonymous::/, 'first app class ok';
like blessed $app2, qr/^Kelp::Anonymous::/, 'second app class ok';

isa_ok $app1, 'Kelp';
isa_ok $app2, 'Kelp';

isnt refaddr $app1->routes, refaddr $app2->routes, 'not the same app routes ok';

$app1->routes->add('/', sub { 'hello' });

isnt
    scalar @{$app1->routes->routes},
    scalar @{$app2->routes->routes},
    'routes storage ok';

# The limitation is that we can't mix ->new and ->new_anon
throws_ok sub {
    $app1 = Kelp->new( mode => 'test' );
    $app2 = Kelp->new_anon( mode => 'test' );
}, qr/Redefining of .+ not allowed/, 'limitations ok';

done_testing;
