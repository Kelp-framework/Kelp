use Kelp::Test;
use HTTP::Request::Common qw/GET PUT POST DELETE/;
use Test::More;

my $t = Kelp::Test->new( psgi => 't/test.psgi' );
$t->request( GET '/say' )->content_is("OK");

done_testing;
