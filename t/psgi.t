use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;
use Test::Exception;

# this application is compatible with the PSGI specification, but is not
# compatible with Kelp (if added to Kelp as-is, the result would be an encoded
# JSON body)
my $psgi_dumper = sub {
    my $env = shift;

    return [
        200,
        ['Content-Type' => 'text/plain'],
        [
            'script: ' . $env->{SCRIPT_NAME} . "\n",
            'path: ' . $env->{PATH_INFO} . "\n",
        ],
    ];
};

my $app = Kelp->new( mode => 'test' );
$app->routes->fatal(1);

$app->add_route('/app1' => {
    to => $psgi_dumper,
    psgi => 1,
});

$app->add_route('/app2/>path' => {
    to => $psgi_dumper,
    psgi => 1,
});

$app->add_route('/app3/:part' => {
    to => $psgi_dumper,
    psgi => 1,
});

throws_ok {
    $app->add_route('/app3' => {
        to => $psgi_dumper,
        psgi => 1,
        bridge => 1,
    });
} qr{'psgi'.+'bridge'};

my $t = Kelp::Test->new( app => $app );

$t->request( GET "/app1" )
  ->code_is(200)
  ->content_like(qr{^script: /app1$}m)
  ->content_like(qr{^path: $}m);

$t->request( GET "/app1/" )
  ->code_is(200)
  ->content_like(qr{^script: /app1$}m)
  ->content_like(qr{^path: /$}m);

$t->request( GET "/app1/x" )
  ->code_is(404);

$t->request( GET "/app2" )
  ->code_is(200)
  ->content_like(qr{^script: /app2$}m)
  ->content_like(qr{^path: $}m);

$t->request( GET "/app2/" )
  ->code_is(200)
  ->content_like(qr{^script: /app2$}m)
  ->content_like(qr{^path: /$}m);

$t->request( GET "/app2/x" )
  ->code_is(200)
  ->content_like(qr{^script: /app2$}m)
  ->content_like(qr{^path: /x$}m);

$t->request( GET "/app2/x/" )
  ->code_is(200)
  ->content_like(qr{^script: /app2$}m)
  ->content_like(qr{^path: /x/$}m);

$t->request( GET "/app2/x/y" )
  ->code_is(200)
  ->content_like(qr{^script: /app2$}m)
  ->content_like(qr{^path: /x/y$}m);

$t->request( GET "/app3" )
  ->code_is(404);

$t->request( GET "/app3/" )
  ->code_is(404);

$t->request( GET "/app3/x" )
  ->code_is(200)
  ->content_like(qr{^script: /app3$}m)
  ->content_like(qr{^path: /x$}m);

$t->request( GET "/app3/x/" )
  ->code_is(200)
  ->content_like(qr{^script: /app3$}m)
  ->content_like(qr{^path: /x/$}m);

$t->request( GET "/app3/x/y" )
  ->code_is(404);

done_testing;

