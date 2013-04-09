
use Kelp::Base -strict;

use Kelp;
use Kelp::Module;
use Test::More;
use Test::Exception;
use Config::Hash;

dies_ok { Kelp::Module->new() } "Dies when no app";

my %types = (
    hash => { bar => 'foo' },
    array  => [ 9, 8, 7 ],
    object => Config::Hash->new,
    code => sub { "Moo!" }
);

my $app = Kelp->new( mode => 'test' );
my $m = Kelp::Module->new( app => $app );
isa_ok $m, 'Kelp::Module';

# Register
for my $name ( keys %types ) {
    my $type = $types{$name};
    $m->register( $name => $type );
    can_ok $app, $name;

    if ( ref $type eq 'CODE' ) {
        is $app->$name, $type->(), "CODE checks out";
    }
    else {
        is_deeply $app->$name, $type, ref($type) . " checks out";
    }
}

# Redefine
for my $name ( keys %types ) {
    my $type = $types{$name};

    # Redefine 'em all one by one.
    for my $t ( values %types ) {
        dies_ok { $m->register( $name => $t ) }
        "Dies when redefining " . ref $t;
    }

    # Now allow redefining and do it again
    $ENV{KELP_REDEFINE} = 1;
    for my $t (values %types) {
        $m->register( $name => $t );
        if ( ref $t eq 'CODE' ) {
            is $app->$name, $t->(), "Redefines CODE";
        }
        else {
            is ref $app->$name, ref $t, "Redefines " . ref $t;
        }
    }
    $ENV{KELP_REDEFINE} = 0;
}

done_testing;
