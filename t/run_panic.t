use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

my $app = Kelp->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

$app->add_route("/die", sub { die "bagels" });
$app->add_route("/undef", sub {});

$t->request( GET '/die' )
  ->code_is(500)
  ->header_is('X-Framework', 'Perl Kelp')
  ->content_like(qr/bagels/);

$t->request( GET '/undef' )
  ->code_is(500)
  ->header_is('X-Framework', 'Perl Kelp')
  ->content_like(qr/did not render/);

# In deployment the error must not show
$app->mode('deployment');
$t->request( GET '/die' )
  ->code_is(500)
  ->header_is('X-Framework', 'Perl Kelp')
  ->content_unlike(qr/bagels/);


# Check if 404 still passes through finalize
$t->request( GET '/none' )
  ->code_is(404)
  ->header_is('X-Framework', 'Perl Kelp');

done_testing;
