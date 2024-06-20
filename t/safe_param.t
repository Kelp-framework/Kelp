use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

my $app = Kelp->new_anon(mode => 'test');
$app->routes->base('main');
my $t = Kelp::Test->new(app => $app);

$app->add_route(
    "/safe/:val" => {
        method => 'GET',
        to => "check_safe",
    }
);

$t->request(GET '/safe/tval?test=sth')
    ->content_is('tval 1 sth');
$t->request(GET '/safe/tval?test=sth&test=sth_else')
    ->content_is('tval 1 sth_else');

done_testing;

sub check_safe
{
    my ($kelp, $val) = @_;

    # list context + parameter to param used to return all parameters with that
    # name (can be multiple)
    my @params = $kelp->param('test');
    my $params = $kelp->param;
    return join ' ', $val, $params, @params;
}

