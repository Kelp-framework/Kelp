use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use Test::More;
use HTTP::Request::Common;

my $cookies = HTTP::Cookies->new;
my $app = Kelp->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

# Request
{
    $app->add_route( '/a' => sub { 1 } );
    $t->request_ok( GET '/a' );
    $t->request( GET '//a' )->code_isnt(200);
}


# Cookies
{
    my $cookie_val = 'kelper';

    # A route to set a cookie
    $app->add_route(
        '/auth',
        sub {
            $_[0]->res->cookies->{foo} = $cookie_val;
            'OK';
        }
    );

    # A route to expect a cookie
    $app->add_route(
        '/user',
        sub {
            $_[0]->req->cookies->{foo};
        }
    );

    $t->request_ok( GET '/auth' );
    $t->request_ok( GET '/user' )->content_is($cookie_val);
}

done_testing;
