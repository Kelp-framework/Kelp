
use strict;
use warnings;

use Test::More;
use Kelp::Routes;

my %h = (
    'a#b'                 => 'A::b',
    'bar#foo'             => 'Bar::foo',
    'bar_foo#baz'         => 'BarFoo::baz',
    'bar_foo#baz_bat'     => 'BarFoo::baz_bat',
    'BarFoo#baz'          => 'Barfoo::baz',
    'barfoo#BAZ'          => 'Barfoo::BAZ',
    'bar_foo_baz_bat#moo' => 'BarFooBazBat::moo',
    'a'                   => 'a',
    'M::D::f'             => 'M::D::f',
    'R_E_S_T#asured'      => 'REST::asured',
    'REST::Assured::ok'   => 'REST::Assured::ok',
    'REST'                => 'REST',
);

for my $k ( keys %h ) {
    is Kelp::Routes::_camelize($k), $h{$k}, $k;
    is Kelp::Routes::_camelize($k, 'Boo'), 'Boo::' . $h{$k}, $k;
}

is Kelp::Routes::_camelize(''), '';

done_testing;
