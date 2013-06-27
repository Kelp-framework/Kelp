
# Allow the redefining of globs at Kelp::Module
BEGIN {
    use FindBin '$Bin';
    $ENV{KELP_REDEFINE} = 1;
    $ENV{KELP_CONFIG_DIR} = "$Bin/../conf";
}

use Kelp::Base -strict;
use Kelp;
use Test::More;
use utf8;

# Basic
my $app = Kelp->new( mode => 'nomod' );
my $m = $app->load_module('Template');
isa_ok $m, 'Kelp::Module::Template';
can_ok $app, $_ for qw/template/;
is $app->template( \"[% a %] ☃", { a => 4 } ), '4 ☃', "Process";

done_testing;

