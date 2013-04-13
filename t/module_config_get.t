BEGIN {
    use FindBin '$Bin';
    $ENV{KELP_CONFIG_DIR} = "$Bin/../conf";
}

use Plack::Util;
use Kelp::Base -strict;
use Kelp::Module::Config;
use Test::More;
use Test::Exception;

my $app = Plack::Util::inline_object(
    mode => sub { "test" },
    path => sub { $ENV{KELP_CONFIG_DIR} }
);
my $c = Kelp::Module::Config->new( app => $app );

# Inject some test data into the config so we can test
$c->data->{test} = {
    a => 1,
    b => 2,
    c => 'bin',
    d => { e => 3 },
    f => { g => { h => { i => 4 } } }
};

is $c->get('charset'), 'UTF-8';
is $c->get('modules_init.JSON.utf8'), 1;
is $c->get('test.a'),       1;
is $c->get('test.d.e'),     3;
is $c->get('test.f.g.h.i'), 4;
is_deeply $c->get('test.f.g.h'), { i => 4 };
is $c->get(''), undef;
is $c->get(), undef;

dies_ok { $c->get('test.b.c') } "Path breaks";

done_testing;
