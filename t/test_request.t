use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use Test::More;
use Test::Deep;
use HTTP::Request::Common;
use URI::Escape;

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
    my $user_cookie_name = '???=';
    my $user_cookie_val = 'what?;value&';

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
        '/user/:name',
        sub {
            $_[0]->req->cookies->{$_[1]};
        }
    );

    $t->cookies->set_cookie(undef, $user_cookie_name, $user_cookie_val);
    $t->request_ok( GET '/auth' );
    $t->request_ok( GET '/user/foo' )->content_is($cookie_val);
    $t->request_ok( GET '/user/' . uri_escape($user_cookie_name) )->content_is($user_cookie_val);

    # check if tester itself handles cookies
    is_deeply
        [$t->cookies->get_cookies(undef, 'foo', $user_cookie_name)],
        [$cookie_val, $user_cookie_val],
        'user cookies ok'
        ;
}

done_testing;

