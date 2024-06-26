BEGIN {
    $ENV{KELP_REDEFINE} = 1;
}

use lib 't/lib';
use Kelp::Base -strict;
use Kelp;
use Test::More;
use Test::Exception;

my $app = Kelp->new;
dies_ok {
    $app->load_module('Shibboleet');
};

# Check if Null module loads
$app->load_module('Null', name => 'value');
pass 'Null module loaded';

# Direct
$app->load_module('Plus', number => 2);
is $app->plus(5), 7;

# Via config
my $bpp = Kelp->new;
$bpp->config_hash->{modules_init}->{Plus} = {
    number => 3
};
$bpp->load_module('Plus');
is $bpp->plus(5), 8;

# Direct overrides
my $cpp = Kelp->new;
$cpp->config_hash->{modules_init}->{Plus} = {
    number => 3
};
$cpp->load_module('Plus', number => 5);
is $cpp->plus(5), 10;

# Fully qualified module name
my $dpp = Kelp->new;
$dpp->config_hash->{modules_init}->{'MyApp::Module::Null'} = {
    number => 4
};
$dpp->load_module('+MyApp::Module::Null');
is $dpp->plus(5), 9;

done_testing;

