use Kelp::Test;
use Kelp::Less mode => 'test';
use HTTP::Request::Common qw/GET PUT POST DELETE/;
use Test::More;

my $t = Kelp::Test->new( app => app );

# route
route '/route' => sub { "A" };
$t->request( GET '/route' )->content_is("A");
$t->request( POST '/route' )->content_is("A");
$t->request( PUT '/route' )->content_is("A");

# get, post, put
get '/get'   => sub { "B" };
post '/post' => sub { "C" };
put '/put'   => sub { "D" };
del '/del'   => sub { "DD" };
$t->request( GET '/get' )->content_is("B");
$t->request( POST '/get' )->code_is(404);
$t->request( GET '/post' )->code_is(404);
$t->request( POST '/post' )->content_is("C");
$t->request( GET '/put' )->code_is(404);
$t->request( POST '/put' )->code_is(404);
$t->request( PUT '/put' )->content_is("D");
$t->request( DELETE '/del' )->content_is("DD");
$t->request( GET '/del' )->code_is(404);

# param
route '/param' => sub { [ sort(param()) ] };
$t->request( GET '/param?a=bar&b=foo' )->json_cmp(['a','b']);
route '/param2' => sub { param 'a' };
$t->request( GET '/param2?a=bar&b=foo' )->content_is("bar");

# session
route '/session' => sub {
    session(bar => 'foo');
    is session('bar'), 'foo';
};

# stash
route '/stash' => sub { stash->{a} = "E"; stash 'a' };
$t->request( GET '/stash' )->content_is("E");

# named
route '/named/:a' => sub { named 'a' };
$t->request( GET '/named/F' )->content_is("F");

# req
route '/req' => sub { ref(req) eq 'Kelp::Request' ? "G" : "FAIL" };
$t->request( POST '/req' )->content_is("G");

# res
route '/res' => sub { ref(res) eq 'Kelp::Response' ? "H" : "FAIL" };
$t->request( POST '/res' )->content_is("H");

# template
route '/template' => sub { template \"[% letter %]", { letter => 'I' } };
$t->request( GET '/template' )->content_is("I");

# attr
attr active => "J";
attr lazy => sub { app->active };
route '/attr' => sub { app->lazy };
$t->request( GET '/attr' )->content_is("J");

# sub
route '/sub' => 'func';
sub func { "K" }
$t->request( GET '/sub' )->content_is("K");

done_testing;
