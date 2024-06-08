package Test;
1;

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
    [qr/neither a string nor a coderef/, '/wrong_to1', { to => [] }],
    [qr/neither a string nor a coderef/, '/wrong_to2', { to => {} }],
    [qr/missing/, '/wrong_to3', { to => undef }],
    [qr/function 'missing' does not exist/, '/wrong_to4', 'missing'],
    [qr/function 'missing' does not exist/, '/wrong_to5', { to => 'missing' }],
    [qr/function '1' does not exist/, '/wrong_to6', { to => 1 }],
    [qr/Can't locate Bar\/_Foo.pm /, '/wrong_to6', { to => 'Bar::_Foo::x' }],
    [qr/method 'x' does not exist in class 'Test'/, '/wrong_to7', { to => 'Test::x' }],
);

subtest 'testing with default fatal' => sub {
    my $r = Kelp::Routes->new;

    for my $case (@cases) {
        $r->add(@{$case} [ 1 .. $#$case ]);
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
        throws_ok { $r->add(@{$case} [ 1 .. $#$case ]) } $case->[0];
    }

    my $routes_count = @{$r->routes};
    is $routes_count, 0, 'routes were not added ok';

    if ($routes_count) {
        diag('existing routes: ' . Dumper($r->routes));
    }
};

done_testing;

