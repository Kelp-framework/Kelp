package TestApp;

use Kelp::Base 'Kelp';

sub hello { }

1;

use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;
use Test::Exception;
use Scalar::Util qw(blessed refaddr);

my ($app1, $app2);

lives_ok sub {
    $app1 = TestApp->new_anon(mode => 'test');
    $app2 = TestApp->new_anon(mode => 'test');
    },
    'construction ok';

ok $app1, 'first anonymous app ok';
ok $app2, 'second anonymous app ok';

like blessed $app1, qr/^Kelp::Anonymous::/, 'first app class ok';
like blessed $app2, qr/^Kelp::Anonymous::/, 'second app class ok';

isa_ok $app1, 'TestApp';
isa_ok $app2, 'TestApp';

isnt refaddr $app1->routes, refaddr $app2->routes, 'not the same app routes ok';
unlike $app1->routes->base, qr/^Kelp::Anonymous::/, 'base ok';

$app1->routes->add('/', 'hello');

isnt
    scalar @{$app1->routes->routes},
    scalar @{$app2->routes->routes},
    'routes storage ok';

is $app1->routes->routes->[0]->to, 'TestApp::hello', 'route destination ok';

# Check for possible string eval problems
throws_ok sub {
    Kelp::new_anon(qq[';#\ndie 'not what was expected']);    # <- try hack the class name
    },
    qr/invalid class for new_anon/i,
    'eval checks ok';

throws_ok sub {
    Kelp::new_anon(undef);    # <- silly but possible usage
    },
    qr/invalid class for new_anon/i,
    'eval checks ok';

# The limitation is that we can't mix ->new and ->new_anon
throws_ok sub {
    $app1 = Kelp->new(mode => 'test');
    $app2 = Kelp->new_anon(mode => 'test');
    },
    qr/redefining of .+ not allowed/i,
    'limitations ok';

done_testing;

