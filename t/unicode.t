use Kelp::Base -strict;

use Kelp;
use Kelp::Test -utf8;
use Test::More;
use HTTP::Request::Common;
use Encode;
use URI::Escape;
use utf8;

my $app = Kelp->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

my $test_string = 'zażółć gęslą jaźń ZAŻÓŁĆ GĘŚLĄ JAŹŃ';

$app->add_route( [ POST => '/path_echo/:echo' ] => sub { return $_[1]; } );
$app->add_route( [ POST => '/body_echo' ] => sub { return $_[0]->param('śś'); } );
$app->add_route( [ POST => '/json_echo' ] => sub { return { 'śś' => $_[0]->param('śś') }; } );

subtest 'path encoding no charset ok' => sub {
    my $string = uri_escape $app->charset_encode($test_string);

    _t("/path_echo/$string", 'application/x-www-form-urlencoded', '', 200, encode($app->charset, $test_string));
};

subtest 'path encoding cp1250 ok' => sub {
    my $string = uri_escape encode 'cp1250', $test_string;

    _t("/path_echo/$string", 'application/x-www-form-urlencoded; charset=cp1250', '', 200, encode($app->charset, $test_string));
};

subtest 'plaintext encoding no charset ok' => sub {
    my $string = join '=', map { uri_escape $app->charset_encode($_) } 'śś', $test_string;

    _t('/body_echo', 'application/x-www-form-urlencoded', $string, 200, encode($app->charset, $test_string));
};

subtest 'plaintext encoding utf8 ok' => sub {
    my $string = join '=', map { uri_escape encode 'utf-8', $_ } 'śś', $test_string;

    _t('/body_echo', 'application/x-www-form-urlencoded; charset=utf-8', $string, 200, encode($app->charset, $test_string));
};

subtest 'plaintext encoding cp1250 ok' => sub {
    my $string = join '=', map { uri_escape encode 'cp1250', $_ } 'śś', $test_string;

    _t('/body_echo', 'application/x-www-form-urlencoded; charset=cp1250', $string, 200, encode($app->charset, $test_string));
};

subtest 'plaintext encoding CP1250 ok' => sub {
    my $string = join '=', map { uri_escape encode 'cp1250', $_ } 'śś', $test_string;

    _t('/body_echo', 'application/x-www-form-urlencoded; CHARSET=CP1250', $string, 200, encode($app->charset, $test_string));
};

subtest 'plaintext encoding unknown is utf8 ok' => sub {
    my $string = join '=', map { uri_escape encode 'utf-8', $_ } 'śś', $test_string;

    _t('/body_echo', 'application/x-www-form-urlencoded; charset=xxnotanencoding', $string, 200, encode($app->charset, $test_string));
};

subtest 'plaintext encoding unknown is not utf8 error ok' => sub {
    my $string = join '=', map { uri_escape encode 'cp1252', $_ } 'śś', $test_string;

    _t('/body_echo', 'application/x-www-form-urlencoded; charset=xxnotanencoding', $string, 500);
};

subtest 'json encoding ok' => sub {
    my $string = Encode::encode('UTF-8', '{"śś":"' . $test_string . '"}');

    _t('/json_echo', 'application/json', $string, 200, $string);
};

sub _t {
    my ( $target, $ct, $content, $code, $expected, %headers) = @_;

    $t->request( POST $target,
        'Content-Type' => $ct,
        %headers,
        'Content' => $content,
    )->code_is($code);

    if ($expected) {
        is $t->res->content, $expected, "expected string to $target ($ct) ok"
    }
}

done_testing;

