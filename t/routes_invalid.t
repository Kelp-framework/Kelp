
use strict;
use warnings;

BEGIN {
    my $DOWARN = 0;
    $SIG{'__WARN__'} = sub { warn $_[0] if $DOWARN }
}

use Test::More;
use Test::Exception;
use Kelp::Routes;
use Data::Dumper;

my @cases = (
    ['/wrong_to1', { to => [] }],
    ['/wrong_to2', { to => {} }],
    ['/wrong_to3', { to => undef }],
    ['/wrong_to4', 'missing'],
    ['/wrong_to5', { to => 'missing' }],
    ['/wrong_to6', { to => 1 }],
    ['/wrong_to6', { to => 'Bar::_Foo::x' }],
);

subtest 'testing with default fatal' => sub {
    my $r = Kelp::Routes->new;

    for my $case (@cases) {
        $r->add(@$case);
    }

    my $routes_count = @{$r->routes};
    is $routes_count, 0, 'routes were not added ok';

    if ($routes_count) {
        diag('existing routes: ' . Dumper($r->routes));
    }
};

subtest 'testing with fatal=1' => sub {
    my $r = Kelp::Routes->new(fatal => 1);

    for my $case (@cases) {
        dies_ok { $r->add(@$case) },
    }

    my $routes_count = @{$r->routes};
    is $routes_count, 0, 'routes were not added ok';

    if ($routes_count) {
        diag('existing routes: ' . Dumper($r->routes));
    }
};

done_testing;

