use lib 't/lib';
use MyApp3::Subclass;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More tests => 4;
use Kelp::Base -strict;

my $app = MyApp3::Subclass->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

$t->request( GET '/greet/jack' )
  ->code_is(200)
  ->content_is("Bonjour, jack");

$t->request( GET '/bye/jack' )
  ->code_is(200)
  ->content_is("Au revoir, jack");

done_testing();
