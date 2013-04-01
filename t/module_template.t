
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
    my $m = $app->load_module('Template');
    isa_ok $m, 'Kelp::Module::Template';
    can_ok $app, $_ for qw/template/;
    is $app->template( \"[% a %]", { a => 4 } ), 4, "Process";
}

done_testing;

