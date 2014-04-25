
use Kelp::Base -strict;
use Kelp;
use Test::More;

# Basic
{
    my $app = Kelp->new( __config => { modules => [] } );
    my $m = $app->load_module('JSON');
    isa_ok $m, "Kelp::Module::JSON";
    can_ok $app, $_ for qw/json/;
    is ref $app->json, 'JSON';
}

done_testing;
