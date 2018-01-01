use lib 't/lib';
use utf8;
use MyApp;
use Test::More;
use Kelp::Test;
use HTTP::Request::Common qw( GET );

my $app = MyApp->new;
my $t   = Kelp::Test->new( app => $app );

is $t->request( GET '/blessed' )->res->code, 200,
   '"path" attr not redefined by import.';
is $app->check_util_fun, "OK",
   '"path" util function still work inside package.';

done_testing;
