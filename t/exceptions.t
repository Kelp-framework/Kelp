use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Kelp::Exception;
use Test::More;

use lib 't/lib';
use StringifyingException;

my $app = Kelp->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

my $ex = StringifyingException->new(data => [qw(ab cd)]);

$app->add_route( "/0", sub { die 'died' });
$t->request( GET "/0" )
    ->code_is(500)
    ->content_like(qr/died/)
    ->content_type_is('text/html');

$app->add_route( "/1", sub { Kelp::Exception->throw(400) });
$app->add_route( "/2", sub { Kelp::Exception->throw(403, body => 'body text') });
$app->add_route( "/2alt", sub { Kelp::Exception->throw(404, body => 'body text') });
$app->add_route( "/5", sub { shift->res->json; Kelp::Exception->throw(500, body => $ex) });
$app->add_route( "/5alt", sub { shift->res->json; Kelp::Exception->throw(501, body => $ex) });
$app->add_route( "/6", sub { Kelp::Exception->throw(300) });

# these errors should be the same regardless of mode
subtest 'testing development' => sub {
    $app->mode('development');

    $t->request( GET "/1" )
        ->code_is(400)
        ->content_is('400 - Bad Request')
        ->content_type_is('text/plain');

    $t->request( GET "/2" )
        ->code_is(403)
        ->content_is('403 - Forbidden')
        ->content_type_is('text/plain');

    $t->request( GET "/2alt" )
        ->code_is(404)
        ->content_like(qr/Four Oh Four/)
        ->content_type_is('text/html');

    $t->request( GET "/5" )
        ->code_is(500)
        ->content_like(qr/\Q$ex\E/)
        ->content_type_is('text/html');

    $t->request( GET "/5alt" )
        ->code_is(501)
        ->content_like(qr/501 - Not Implemented/)
        ->content_type_is('text/plain');

    $t->request( GET "/6" )
        ->code_is(500)
        ->content_like(qr/5XX/)
        ->content_type_is('text/html');
};

subtest 'testing deployment' => sub {
    $app->mode('deployment');

    $t->request( GET "/1" )
        ->code_is(400)
        ->content_is('400 - Bad Request')
        ->content_type_is('text/plain');

    $t->request( GET "/2" )
        ->code_is(403)
        ->content_is('403 - Forbidden')
        ->content_type_is('text/plain');

    $t->request( GET "/2alt" )
        ->code_is(404)
        ->content_like(qr/Four Oh Four/)
        ->content_type_is('text/html');

    $t->request( GET "/5" )
        ->code_is(500)
        ->content_unlike(qr/Exception/)
        ->content_type_is('text/html');

    $t->request( GET "/5alt" )
        ->code_is(501)
        ->content_is('501 - Not Implemented')
        ->content_type_is('text/plain');

    $t->request( GET "/6" )
        ->code_is(500)
        ->content_like(qr/Five Hundred/)
        ->content_type_is('text/html');
};


done_testing;

