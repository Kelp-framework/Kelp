use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;
use Plack::Builder;

my $app = Kelp->new(mode => 'test', __config => 1);
$app->routes->base("main");

sub add_x_header
{
    my $name = shift;
    sub {
        my $app = shift;
        return sub {
            my $ret = $app->($_[0]);
            push @{$ret->[1]}, "X_$name", 'OK';
            return $ret;
        };
    };
}

$app->add_route('/mw', sub { "OK" });

$app->add_route(
    '/mw/*', {
        to => sub { 1 },
        bridge => 1,
        psgi_middleware => builder {
            enable add_x_header('TestBridge');
            Kelp->NEXT_APP;
        },
    }
);

$app->add_route(
    '/mw/2', {
        to => sub { "OK" },
        psgi_middleware => builder {
            enable add_x_header('Test1');
            Kelp->NEXT_APP;
        },
    }
);

$app->add_route(
    '/mw/2/3', {
        to => sub { "OK" },
        psgi_middleware => builder {
            enable add_x_header('Test2');
            Kelp->NEXT_APP;
        },
    }
);

my $t = Kelp::Test->new(app => $app);

# No middleware
$t->request(GET '/mw')
    ->header_is("X-Framework", "Perl Kelp");

# Add middleware
$app->_cfg->merge(
    {
        middleware => ['XFramework', 'ContentLength'],
        middleware_init => {
            XFramework => {
                framework => 'Changed'
            }
        }
    }
);

$t->request(GET '/mw')
    ->header_is("X-Framework", "Changed")
    ->header_is("Content-Length", 2);

$t->request(GET '/mw/2')
    ->header_is("X-TestBridge", "OK")
    ->header_is("X-Test1", "OK")
    ->header_isnt("X-Test2", "OK")
    ->header_is("X-Framework", "Changed")
    ->header_is("Content-Length", 2);

$t->request(GET '/mw/2/3')
    ->header_is("X-TestBridge", "OK")
    ->header_isnt("X-Test1", "OK")
    ->header_is("X-Test2", "OK")
    ->header_is("X-Framework", "Changed")
    ->header_is("Content-Length", 2);

done_testing;

