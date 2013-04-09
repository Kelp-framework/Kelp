use Kelp::Base -strict;
use Kelp::Test;
use Test::More;
use HTTP::Request::Common;

my $t = Kelp::Test->new( psgi => 't/test.psgi' );

$t->request( GET '/home' )
  ->code_is(200)
  ->content_type_is('text/html')
  ->content_is("Hello, world!");

done_testing;
