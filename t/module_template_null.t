
# Allow the redefining of globs at Kelp::Module
BEGIN {
    use FindBin '$Bin';
    $ENV{KELP_REDEFINE} = 1;
    $ENV{KELP_CONFIG_DIR} = "$Bin/conf/template";
}

use Kelp;
use Kelp::Base -strict;
use Test::More;

# Basic
my $app = Kelp->new();
is $app->template(), "All the ducks";
is $app->template("something", { bar => 'foo' }), "All the ducks";

done_testing;
