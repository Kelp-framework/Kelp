
# Allow the redefining of globs at Kelp::Module
BEGIN {
    $ENV{KELP_REDEFINE} = 1;
}

use Kelp::Base -strict;
use Kelp;
use Kelp::Test;
use Test::More;
use HTTP::Request::Common;

# Levels
{
    my $app = Kelp->new( mode => 'nomod' );
    my $m = $app->load_module('Logger');

    isa_ok $m, "Kelp::Module::Logger";
    can_ok $app, $_ for qw/error debug/;

    my $t = Kelp::Test->new(app => $app);
    $app->add_route('/log', sub {
        my $self = shift;
        $self->debug("Debug message");
        $self->error("Error message");
        $self->logger('critical', "Critical message");
        "ok";
    });
    $t->request(GET '/log')->code_is(200);
}

done_testing;
