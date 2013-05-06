use Kelp::Base -strict;

use Kelp;
use Kelp::Response;
use Test::More;

my $app = Kelp->new( mode => 'test' );
my $r = Kelp::Response->new( app => $app );

$r->text;
$r->set_code(200);
my $A = $r->finalize;

$r->partial(1);
my $B = $r->finalize;

is scalar(@$A), 3;
is scalar(@$B), 2;
is $A->[0], $B->[0];
is_deeply $A->[1], $B->[1];

done_testing;
