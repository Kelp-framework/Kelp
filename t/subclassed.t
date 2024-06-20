use lib 't/lib';
use Kelp::Base -strict;
use MyApp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;
use Test::Exception;

my $app = MyApp->new(mode => 'test');
my $t = Kelp::Test->new(app => $app);

$t->request(GET '/test')
    ->code_isnt(500)
    ->content_is("OK")
    ->content_isnt("FAIL")
    ->header_is("X-Before-Dispatch", "MyApp")
    ->header_is("X-Test", "MyApp")
    ->header_isnt("X-Framework", "Perl Kelp");

$t->request(GET '/missing')
    ->code_is(404)
    ->content_is("NO");

$t->request(GET '/greet/jack')
    ->code_is(200)
    ->content_is("OK jack");

$t->request(GET '/bye/jack')
    ->code_is(200)
    ->content_is("BYE jack");

done_testing;

