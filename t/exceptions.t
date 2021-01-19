use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Kelp::Exception;
use Test::More;

my $app = Kelp->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

$app->add_route( "/0", sub { die 'died' });
$t->request( GET "/0" )
    ->code_is(500)
    ->content_like(qr/died/)
    ->content_type_is('text/html');

$app->add_route( "/1", sub { Kelp::Exception->throw(400) });
$app->add_route( "/2", sub { Kelp::Exception->throw(403, body => 'body text') });
$app->add_route( "/3", sub { Kelp::Exception->throw(501, body => {json => 'object'}) });
$app->add_route( "/4", sub { Kelp::Exception->throw(503, body => [qw(json array)]) });
$app->add_route( "/5", sub { shift->res->json; Kelp::Exception->throw(500) });

# these errors should be the same regardless of mode
for (qw(deployment development)) {
    $app->mode($_);

    $t->request( GET "/1" )
        ->code_is(400)
        ->content_is('')
        ->content_type_is('');

    $t->request( GET "/2" )
        ->code_is(403)
        ->content_is('body text')
        ->content_type_is('text/html');

    $t->request( GET "/3" )
        ->code_is(501)
        ->content_is('{"json":"object"}')
        ->content_type_is('application/json');

    $t->request( GET "/4" )
        ->code_is(503)
        ->content_is('["json","array"]')
        ->content_type_is('application/json');

    $t->request( GET "/5" )
        ->code_is(500)
        ->content_is('')
        ->content_type_is('');

}

$app->add_route( "/6", sub { Kelp::Exception->throw(300) });
$t->request( GET "/6" )
    ->code_is(500)
    ->content_like(qr/5XX/)
    ->content_type_is('text/html');

done_testing;
