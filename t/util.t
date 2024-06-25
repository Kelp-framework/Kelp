
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Kelp::Util;

subtest 'testing camelize' => sub {
    my %h = (
        'a#b' => 'A::b',
        'bar#foo' => 'Bar::foo',
        'bar_foo#baz' => 'BarFoo::baz',
        'bar_foo#baz_bat' => 'BarFoo::baz_bat',
        'BarFoo#baz' => 'Barfoo::baz',
        'barfoo#BAZ' => 'Barfoo::BAZ',
        'bar_foo_baz_bat#moo' => 'BarFooBazBat::moo',
        'a' => 'a',
        'M::D::f' => 'M::D::f',
        'R_E_S_T#asured' => 'REST::asured',
        'REST::Assured::ok' => 'REST::Assured::ok',
        'REST' => 'REST',
    );

    for my $k (keys %h) {
        is(Kelp::Util::camelize($k), $h{$k}, "base $k");
        is(Kelp::Util::camelize($k, 'Boo'), 'Boo::' . $h{$k}, "$k with namespace");
        is(Kelp::Util::camelize($k, ''), $h{$k}, "$k with empty namespace");
    }

    is(Kelp::Util::camelize(''), '', 'empty ok');
    is(Kelp::Util::camelize('', 'Boo'), '', 'empty with class ok');
};

subtest 'testing camelize (class only)' => sub {
    my %h = (
        'a#b' => 'A::B',
        'bar#foo' => 'Bar::Foo',
        'bar_foo#baz' => 'BarFoo::Baz',
        'bar_foo#baz_bat' => 'BarFoo::BazBat',
        'BarFoo#baz' => 'Barfoo::Baz',
        'barfoo#BAZ' => 'Barfoo::Baz',
        'bar_foo_baz_bat#moo_moo' => 'BarFooBazBat::MooMoo',
        'a' => 'A',
        'M::D::f' => 'M::D::f',
        'R_E_S_T#asured' => 'REST::Asured',
        'REST::Assured::ok' => 'REST::Assured::ok',
        'REST' => 'Rest',
    );

    for my $k (keys %h) {
        is(Kelp::Util::camelize($k, undef, 1), $h{$k}, "base $k");
        is(Kelp::Util::camelize($k, 'Boo', 1), 'Boo::' . $h{$k}, "$k with namespace");
        is(Kelp::Util::camelize($k, '', 1), $h{$k}, "$k with empty namespace");
    }

    is(Kelp::Util::camelize('', undef, 1), '', 'empty ok');
    is(Kelp::Util::camelize('', 'Boo', 1), '', 'empty with class ok');
};

subtest 'testing extract_class' => sub {
    my %h = (
        'A::b' => 'A',
        'Bar::foo' => 'Bar',
        'BarFoo::baz' => 'BarFoo',
        'BarFooBazBat::moo' => 'BarFooBazBat',
        'a' => undef,
        'M::D::f' => 'M::D',
        'REST::Assured::ok' => 'REST::Assured',
        'main::ok' => undef,
        '' => undef,
    );

    for my $k (keys %h) {
        if (defined $h{$k}) {
            is(Kelp::Util::extract_class($k), $h{$k}, $k);
        }
        else {
            ok !defined Kelp::Util::extract_class($k), $k;
        }
    }

};

subtest 'testing extract_function' => sub {
    my %h = (
        'A::b' => 'b',
        'BarFoo::baz' => 'baz',
        'a' => 'a',
        'M::D::f' => 'f',
        '' => undef,
    );

    for my $k (keys %h) {
        if (defined $h{$k}) {
            is(Kelp::Util::extract_function($k), $h{$k}, $k);
        }
        else {
            ok !defined Kelp::Util::extract_function($k), $k;
        }
    }
};

subtest 'testing load_package' => sub {
    Kelp::Util::load_package('Kelp::Module::Logger::Simple');
    can_ok 'Kelp::Module::Logger::Simple', 'build';

    throws_ok {
        Kelp::Util::load_package('This::Package::Does::Not::Exist');
    } qr{This/Package/Does/Not/Exist.pm};

    note $@;
};

done_testing;

