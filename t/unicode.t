use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use Test::More;
use HTTP::Request::Common;
use Encode;
use URI::Escape;
use utf8;

my $app = Kelp->new(mode => 'test');
my $t = Kelp::Test->new(app => $app);

my $test_string = 'zażółć gęslą jaźń ZAŻÓŁĆ GĘŚLĄ JAŹŃ&=#?';

$app->add_route([POST => '/path_echo/:echo'] => sub { return $_[1]; });
$app->add_route([POST => '/form_echo'] => sub { return $_[0]->param('śś'); });
$app->add_route([POST => '/json_echo'] => sub { return {'śś' => $_[0]->param('śś')}; });
$app->add_route([POST => '/no_encoding'] => sub { return $_[0]->param('encoded'); });

subtest 'path encoding no charset ok' => sub {

    # NOTE: path must be in utf8
    my $string = uri_escape_utf8 $test_string;

    _t("/path_echo/$string", 'text/plain', '', 200, encode($app->charset, $test_string));
};

subtest 'plaintext encoding no charset ok' => sub {
    my $string = join '=', map { uri_escape(encode $app->request_charset, $_) } 'śś', $test_string;

    _t('/form_echo', 'application/x-www-form-urlencoded', $string, 200, encode($app->charset, $test_string));
};

subtest 'plaintext encoding utf8 ok' => sub {
    my $string = join '=', map { uri_escape_utf8($_) } 'śś', $test_string;

    _t(
        '/form_echo', 'application/x-www-form-urlencoded; charset=utf-8',
        $string, 200, encode($app->charset, $test_string)
    );
};

subtest 'plaintext encoding cp1250 ok' => sub {
    my $string = join '=', map { uri_escape(encode 'cp1250', $_) } 'śś', $test_string;

    _t(
        '/form_echo', 'application/x-www-form-urlencoded; charset=cp1250',
        $string, 200, encode($app->charset, $test_string)
    );
};

subtest 'plaintext encoding CP1250 ok' => sub {
    my $string = join '=', map { uri_escape(encode 'cp1250', $_) } 'śś', $test_string;

    _t(
        '/form_echo', 'application/x-www-form-urlencoded; CHARSET=CP1250',
        $string, 200, encode($app->charset, $test_string)
    );
};

subtest 'plaintext encoding unknown is utf8 ok' => sub {
    my $string = join '=', map { uri_escape_utf8($_) } 'śś', $test_string;

    _t(
        '/form_echo', 'application/x-www-form-urlencoded; charset=xxnotanencoding',
        $string, 200, encode($app->charset, $test_string)
    );
};

subtest 'plaintext encoding unknown is not utf8 error ok' => sub {
    my $string = join '=', map { uri_escape(encode 'cp1252', $_) } 'śś', $test_string;

    _t('/form_echo', 'application/x-www-form-urlencoded; charset=xxnotanencoding', $string, 500);
};

subtest 'json UTF-32 encoding ok' => sub {
    my $json_string = '{"śś":"' . $test_string . '"}';
    my $string = encode('UTF-32', $json_string);

    _t('/json_echo', 'application/json; charset=UTF-32', $string, 200, encode($app->charset, $json_string));
};

# TESTING UTF-16 FROM NOW ON
$app->charset('UTF-16');

subtest 'template encoding on 404 page ok' => sub {
    _t("/unknown", 'text/plain', '', 404, encode($app->charset, "Four Oh Four: Not Found\n\n"));
};

subtest 'query encoding no charset on utf16 ok' => sub {

    # NOTE: path must be in utf8
    my $key = uri_escape_utf8 'śś';
    my $string = uri_escape_utf8 $test_string;

    _t("/form_echo/?$key=$string", 'text/plain', '', 200, encode($app->charset, $test_string));
};

# FIXME: this won't really work with non-ascii and charsets inside each part...
# the content is charset-decoded AFTER it is parsed already, so body must be in
# ascii-compatible encoding. On the other hand, the information about encoding
# of each part is lost on Plack level. Would require rewriting the multipart
# parser to get this right.
subtest 'muiltpart encoding without charsets on utf16 ok' => sub {
    my $string = encode 'UTF-8', <<MULTIPART;
----multipartformdatakelptest\r
Content-Disposition: form-data; name="śś";\r
Content-Type: text/plain\r
\r
$test_string\r
----multipartformdatakelptest--\r
MULTIPART

    _t(
        '/form_echo', 'multipart/form-data; boundary=--multipartformdatakelptest',
        $string, 200, encode($app->charset, $test_string)
    );
};

# TESTING NO CHARSET FROM NOW ON
$app->charset(undef);
$app->request_charset(undef);

subtest 'ignoring charset if application has no charset configured ok' => sub {
    my $string = join '=', map { uri_escape_utf8($_) } 'encoded', $test_string;

    _t(
        '/no_encoding', 'application/x-www-form-urlencoded; charset=CP1250',
        $string, 200, encode('UTF-8', $test_string)
    );
    $t->full_content_type_is('text/html');
};

sub _t
{
    my ($target, $ct, $content, $code, $expected, %headers) = @_;

    $t->request(
        POST $target,
        'Content-Type' => $ct,
        %headers,
        'Content' => $content,
    )->code_is($code);

    if ($expected) {
        $t->content_bytes_are($expected, "expected string to $target ($ct) ok");
    }
}

done_testing;

