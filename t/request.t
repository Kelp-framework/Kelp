use Kelp::Base -strict;

use Kelp;
use Kelp::Test -utf8;
use HTTP::Request::Common;
use Test::More;
use utf8;

my $app = Kelp->new(mode => 'test');
my $t = Kelp::Test->new(app => $app);

# is_json
$app->add_route(
    '/req_method',
    sub {
        my $method = $_[0]->req->query_param('m');
        return $_[0]->req->$method ? "ok" : "fail";
    }
);
for my $ct (
    'application/json',
    'application/json; charset=UTF-8',
    'APPLICATION/json; charset=UTF-8',
    'APPLICATION/JSON; somethin=blah'
    )
{
    $t->request(GET '/req_method?m=is_json', Content_Type => $ct)
        ->code_is(200)
        ->content_is('ok');
}

$t->request(GET '/req_method?m=is_ajax', 'X-Requested-With' => 'XMLHttpRequest')
    ->code_is(200)
    ->content_is('ok');

$t->request(GET '/req_method?m=is_ajax')
    ->code_is(200)
    ->content_is('fail');

$t->request(GET '/req_method?m=is_text', Content_Type => 'text/plain')
    ->code_is(200)
    ->content_is('ok');

$t->request(GET '/req_method?m=is_text', Content_Type => 'text/html')
    ->code_is(200)
    ->content_is('fail');

$t->request(GET '/req_method?m=is_html', Content_Type => 'text/html')
    ->code_is(200)
    ->content_is('ok');

$t->request(GET '/req_method?m=is_html', Content_Type => 'text/plain')
    ->code_is(200)
    ->content_is('fail');

$t->request(GET '/req_method?m=is_xml', Content_Type => 'application/xml')
    ->code_is(200)
    ->content_is('ok');

$t->request(GET '/req_method?m=is_xml', Content_Type => 'application/json')
    ->code_is(200)
    ->content_is('fail');

# param
$app->add_route(
    '/param/:n',
    sub {
        my ($self, $n) = @_;
        if ($n == 1) {
            [sort($self->param)];
        }
        elsif ($n == 2) {
            my %h = map { $_ => $self->param($_) } $self->param;
            return \%h;
        }
        elsif ($n == 3) {
            return $self->req->json_content // {};
        }
    }
);
$t->request(
    POST '/param/1',
    'Content-Type' => 'application/json',
    'Content' => '{"a":"bar","b":"foo"}'
    )
    ->code_is(200)
    ->json_cmp(['a', 'b'], "Get JSON list of params");

$t->request(
    POST '/param/2',
    'Content-Type' => 'application/json',
    'Content' => '{"a":"bar","b":"foo"}'
    )
    ->code_is(200)
    ->json_cmp({a => "bar", b => "foo"}, "JSON array context");

$t->request(
    POST '/param/3',
    'Content-Type' => 'application/json',
    'Content' => '{"a":"bar","b":"foo"}'
    )
    ->code_is(200)
    ->json_cmp({a => "bar", b => "foo"}, "JSON scalar context");

# No JSON content
$t->request(POST '/param/3', 'Content-Type' => 'application/json')
    ->code_is(200)
    ->json_cmp({}, "No JSON content");

# JSON content is not a hash
$t->request(
    POST '/param/3',
    'Content-Type' => 'application/json',
    'Content' => '[1,2,3]'
    )
    ->code_is(200)
    ->json_cmp([1, 2, 3], "JSON content is not a hash");

$t->request(POST '/param/1', [a => "bar", b => "foo"])
    ->code_is(200)
    ->json_cmp(['a', 'b'], "Get POST list of params");

$t->request(POST '/param/2', [a => "bar", b => "foo"])
    ->code_is(200)
    ->json_cmp({a => "bar", b => "foo"}, "POST array context");

# UTF8
my $utf_hash = {
    english => 'Well done',
    russian => 'Молодец'
};
$app->add_route('/json/utf', sub { $utf_hash });
$t->request(GET '/json/utf')->json_cmp($utf_hash);

# Make sure legacy 'via' attribute works for backwards
# compatibiliry
$app->add_route(
    '/via_legacy', {
        via => 'POST',
        to => sub { "OK" }
    }
);
$t->request(POST 'via_legacy')
    ->code_is(200)
    ->content_is("OK");

done_testing;

