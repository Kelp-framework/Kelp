use Kelp::Base -strict;
use Test::More;
use Kelp::Test;
use HTTP::Request::Common;
use lib 't/lib';
use JsonError;

my $app = JsonError->new;
my $t = Kelp::Test->new( app => $app );

# Check if json encoding does not cause json response enconding error (json
# content type + non-reference body). This happened in the past because json
# content type was set before encoding and not cleared when an error occured.

subtest 'testing mode development' => sub {
    $app->mode('development');

    $t->request( GET '/json' )
        ->code_is(500)
        ->content_unlike(qr{Don't know how to handle non-json reference});

    $t->request( GET '/forced-json' )
        ->code_is(500)
        ->content_unlike(qr{Don't know how to handle non-json reference});
};

subtest 'testing mode deployment' => sub {
    $app->mode('deployment');

    $t->request( GET '/json' )
        ->code_is(500)
        ->content_like(qr{Five Hundred});

    $t->request( GET '/forced-json' )
        ->code_is(500)
        ->content_like(qr{Five Hundred});
};

done_testing;

