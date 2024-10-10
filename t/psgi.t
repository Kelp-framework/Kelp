use Kelp::Base -strict;

use Kelp;
use Kelp::Test -utf8;
use HTTP::Request::Common;
use Test::More;
use Test::Exception;
use URI::Escape;
use Encode;
use utf8;

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

# this is a PSGI app which compares env keys
my $psgi_comparer = sub {
    my $env = shift;

    my %env_before = %$env;
    my $res = Kelp->NEXT_APP->($env);

    my $all_valid = 1;
    foreach my $key (keys %env_before) {
        my $value = $env_before{$key};
        next if ref $value;

        $all_valid &&= $value eq $env->{$key};
    }

    if (!$all_valid) {
        push @{$res->[2]}, "BADENV\n";
    }

    return $res;
};

my $app = Kelp->new(mode => 'test');
$app->routes->fatal(1);

$app->add_route(
    '/' => {
        to => sub { 1 },
        bridge => 1,
        psgi_middleware => $psgi_comparer,
    }
);

$app->add_route(
    '/app1' => {
        to => $psgi_dumper,
        psgi => 1,
    }
);

$app->add_route(
    '/app2/>path' => {
        to => $psgi_dumper,
        psgi => 1,
    }
);

$app->add_route(
    '/app3/:part' => {
        to => $psgi_dumper,
        psgi => 1,
    }
);

throws_ok {
    $app->add_route(
        '/invalid' => {
            to => $psgi_dumper,
            psgi => 1,
            bridge => 1,
        }
    );
} qr{'psgi'.+'bridge'};

my $t = Kelp::Test->new(app => $app);

$t->request(GET "/app1")
    ->code_is(200)
    ->content_like(qr{^script: /app1$}m)
    ->content_like(qr{^path: $}m)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app1/")
    ->code_is(200)
    ->content_like(qr{^script: /app1$}m)
    ->content_like(qr{^path: /$}m)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app1/x")
    ->code_is(404)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app2")
    ->code_is(200)
    ->content_like(qr{^script: /app2$}m)
    ->content_like(qr{^path: $}m)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app2/")
    ->code_is(200)
    ->content_like(qr{^script: /app2$}m)
    ->content_like(qr{^path: /$}m)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app2/x")
    ->code_is(200)
    ->content_like(qr{^script: /app2$}m)
    ->content_like(qr{^path: /x$}m)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app2/x/")
    ->code_is(200)
    ->content_like(qr{^script: /app2$}m)
    ->content_like(qr{^path: /x/$}m)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app2/x/y")
    ->code_is(200)
    ->content_like(qr{^script: /app2$}m)
    ->content_like(qr{^path: /x/y$}m)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app3")
    ->code_is(404)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app3/")
    ->code_is(404)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app3/x")
    ->code_is(200)
    ->content_like(qr{^script: /app3$}m)
    ->content_like(qr{^path: /x$}m)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app3/x/")
    ->code_is(200)
    ->content_like(qr{^script: /app3$}m)
    ->content_like(qr{^path: /x/$}m)
    ->content_unlike(qr{^BADENV$}m);

$t->request(GET "/app3/x/y")
    ->code_is(404)
    ->content_unlike(qr{^BADENV$}m);

# application unicode support should be distinct from Kelp. Kelp will just have
# to pass everything to the app through psgi env undecoded. App result should
# not be encoded either, it should do its own encoding and decoding. Paths are
# always in UTF-8 or ASCII, so Kelp should handle that as well.
subtest 'testing unicode' => sub {
    $t->charset('UTF-8');
    $app->charset('UTF-16');

    $app->add_route(
        '/zażółć/>part' => {
            to => $psgi_dumper,
            psgi => 1,
        }
    );

    my $script = uri_escape_utf8 'zażółć';
    my @path = map { uri_escape_utf8 $_ } 'gęślą', 'jaźń';
    $t->request(GET '/' . (join '/', $script, @path))
        ->code_is(200)
        ->full_content_type_is('text/plain')
        ->content_like(qr{^script: /zażółć$}m)
        ->content_like(qr{^path: /gęślą/jaźń$}m)
        ->content_unlike(qr{^BADENV$}m);
};

done_testing;

