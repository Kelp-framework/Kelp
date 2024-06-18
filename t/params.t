use Kelp::Base -strict;

use Kelp;
use Kelp::Test -utf8;
use Test::More;
use HTTP::Request::Common;
use Encode;
use URI::Escape;
use utf8;

my $app = Kelp->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

$app->add_route( [ POST => '/dump_params/:field' ] => sub {
    my ( $self, $field ) = @_;
    my $req = $self->req;

    return {
        param => $req->param( $field ),
        query_param => $req->query_param( $field ),
        body_param => $req->body_param( $field ),
        json_param => $req->json_param( $field ),
    };
} );

my $target = '/dump_params/fld?fld=query';

subtest 'testing normal request' => sub {
    $t->request( POST $target,
        'Content-Type' => 'application/x-www-form-urlencoded',
        'Content' => 'fld=body',
    )->code_is(200);

    $t->json_cmp({
        param => 'body',
        query_param => 'query',
        body_param => 'body',
        json_param => undef,
    });
};

subtest 'testing json request' => sub {
    $t->request( POST $target,
        'Content-Type' => 'application/json',
        'Content' => '{"fld": "json"}',
    )->code_is(200);

    $t->json_cmp({
        param => 'json',
        query_param => 'query',
        body_param => undef,
        json_param => 'json',
    });
};

done_testing;

