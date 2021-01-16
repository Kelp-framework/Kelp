use Kelp::Base -strict;
use Test::More;
use Kelp::Test;
use HTTP::Request::Common;
use lib 't/lib';
use JsonError;

my $app = JsonError->new;
my $t = Kelp::Test->new( app => $app );

# Check if json encoding does not cause json response enconding error
# This happened in the past beacuse json content type was set before encoding

$t->request( GET '/json' )
    ->code_is(500)
    ->content_unlike(qr{Data must be a reference});

# TODO: This can be hopefully fixed in the future, but it requires more risky
# changes
$t->request( GET '/forced-json' )
    ->code_is(500)
    ->content_like(qr{Data must be a reference});

done_testing;
