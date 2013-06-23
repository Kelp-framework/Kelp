use Kelp::Base -strict;
use Kelp;
use Test::More;
use FindBin '$Bin';

BEGIN {
    $ENV{KELP_CONFIG_DIR} = "$Bin/conf/disable";
    $ENV{KELP_REDEFINE} = 1;
}

my $a = Kelp->new( mode => 'test' );
ok $a->can('json');
ok !$a->can('template');

my $b = Kelp->new( mode => 'test2' );
ok $a->can('json');
ok $a->can('template');

done_testing;
