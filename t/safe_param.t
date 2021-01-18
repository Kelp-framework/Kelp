use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

my $app = Kelp->new_anon( mode => 'test' );
$app->routes->base('main');
my $t = Kelp::Test->new(app => $app);

$app->add_route(
    "/safe" => {
        method => 'GET',
        to   => "check_safe",
    }
);

for my $is_safe (0 .. 1) {
    $app->config_hash->{safe_param} = $is_safe;

    $t->request(GET '/safe?test=sth')
        ->content_is('sth');
    $t->request(GET '/safe?test=sth&test=sth_else')
        ->content_is($is_safe ? 'sth_else' : 'sth sth_else');
}

done_testing;

sub check_safe {
    my ($kelp) = @_;

    # list context + parameter to param used to return all parameters with that
    # name (can be multiple)
    my @params = $kelp->param('test');
    return join ' ', @params;
}
