BEGIN {
    $ENV{KELP_REDEFINE} = 1;
}

use Kelp::Base -strict;
use Kelp;
use Test::More;
use Test::Exception;

my $app = Kelp->new;
dies_ok {
    $app->load_module('Shibboleet');
};

# Direct
$app->load_module( 'Null', number => 2 );
is $app->plus(5), 7;

# Via config
my $bpp = Kelp->new;
$bpp->config_hash->{modules_init}->{Null} = {
    number => 3
};
$bpp->load_module( 'Null' );
is $bpp->plus(5), 8;

# Direct overrides
my $cpp = Kelp->new;
$cpp->config_hash->{modules_init}->{Null} = {
    number => 3
};
$cpp->load_module( 'Null', number => 5 );
is $cpp->plus(5), 10;

done_testing;



