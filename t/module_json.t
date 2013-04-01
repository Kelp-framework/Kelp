
# Allow the redefining of globs at Kelp::Module
BEGIN {
    $ENV{KELP_REDEFINE} = 1;
}

use Kelp::Base -strict;
use Kelp;
use Test::More;

# Basic
{
    my $app = Kelp->new( mode => 'nomod' );
    my $m = $app->load_module('JSON');
    isa_ok $m, "Kelp::Module::JSON";
    can_ok $app, $_ for qw/json/;
    is ref $app->json, 'JSON';
}

done_testing;
