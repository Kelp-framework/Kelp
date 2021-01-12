use strict;
use warnings;
use Test::More;
use Kelp::Module::Config;
use Kelp;

BEGIN {
    use FindBin '$Bin';
    $ENV{KELP_CONFIG_DIR} = "$Bin/conf/process_mode";
}

my $app = Kelp->new;
my $c = Kelp::Module::Config->new( app => $app, data => { foo => 1 } );

$c->process_mode('missing');
is_deeply $c->data, { foo => 1 };

$c->process_mode('a');
is_deeply $c->data, { foo => 1, bar => 1 };

$c->process_mode('b');
is_deeply $c->data, { foo => 1, bar => 1, baz => 1 };

done_testing;
