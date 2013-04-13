
# Allow the redefining of globs at Kelp::Module
BEGIN {
    use FindBin '$Bin';
    $ENV{KELP_REDEFINE} = 1;
    $ENV{KELP_CONFIG_DIR} = "$Bin/conf/null";
}

use Kelp;
use Kelp::Base -strict;
use Test::More;

# Basic
my $app = Kelp->new( config_module => 'Config::Null' );
is $app->config("injected"), 1;
is $app->config("shoulda"), undef;

done_testing;
