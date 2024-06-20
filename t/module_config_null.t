$ENV{KELP_REDEFINE} = 1;

# Allow the redefining of globs at Kelp::Module
BEGIN {
    use FindBin '$Bin';
    $ENV{KELP_CONFIG_DIR} = "$Bin/conf/null";
}

use lib 't/lib';
use Kelp;
use Kelp::Base -strict;
use Test::More;
use Test::Deep;

subtest 'testing null config' => sub {
    my $app = Kelp->new(config_module => 'Config::Null');
    is_deeply $app->config_hash, {}, 'null module ok';
};

subtest 'testing least config' => sub {
    my $app = Kelp->new(config_module => 'Config::Least');
    is_deeply $app->config_hash, {shoulda => 'This will not get into Injected'}, 'null module ok';
};

subtest 'testing injected config' => sub {
    my $app = Kelp->new(config_module => 'Config::Injected');
    is $app->config("injected"), 1;
    is $app->config("shoulda"), undef;
};

done_testing;

