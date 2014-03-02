
package B1;
use Kelp::Base;

attr bar => 1;
attr foo => sub{{ a => 1 }};
attr baz => sub{[1,2,3,4]};
attr bat => sub {
    $_[0]->bar( $_[0]->bar + 1 );
    $_[0]->bar;
};
attr color => sub { $_[0]->_build_color };
attr -ro => 9;
attr un => sub { undef };

sub _build_color { "red" }

package B2;
use Kelp::Base 'B1';

attr bar => 10;
sub _build_color { "green" }

package B3;
use Kelp::Base 'B2';

attr bar => 100;
sub _build_color { "blue" }

package C1;
use Kelp::Base -strict;
sub new { bless {}, $_[0] }

package main;
use Test::More;

my $o = B1->new;

isa_ok $o, 'B1';
can_ok $o, qw/bar foo baz bat ro un/;
is $o->bar, 1;
is_deeply $o->foo, { a => 1 };
is_deeply $o->baz, [1,2,3,4];
is $o->bat, 2;
is $o->bat, 2;

# undef
is $o->un, undef;
$o->un(1);
is $o->un, 1;
$o->un(undef);
is $o->un, undef;

$o->bar(3);
is $o->bar, 3;

$o->foo({ a => 2 });
is_deeply $o->foo, { a => 2 };

$o->baz({ b => 2 });
is_deeply $o->baz, { b => 2 };

is $o->color, "red";

# Readonly
is $o->ro, 9;
$o->ro(10);
is $o->ro, 9;

my $oo = B1->new( ro => 6 );
is $oo->ro, 6;
$oo->ro(7);
is $oo->ro, 6;

my $p = B2->new;
isa_ok $p, 'B2';
ok $p->can($_) for qw/bar foo baz bat/;

is $p->bar, 10;
is_deeply $p->foo, { a => 1 };
is_deeply $p->baz, [1,2,3,4];
is $p->bat, 11;
is $p->bat, 11;

is $p->color, "green";

my $q = B2->new( bar => 20, baz => {a => 6} );
is $q->bar, 20;
is_deeply $q->baz, { a => 6 };
is $q->bat, 21;
is $q->bat, 21;

my $r = B3->new;
isa_ok $r, 'B3';
ok $r->can($_) for qw/bar foo baz bat/;

is $r->bar, 100;
is $r->color, "blue";

my $pp = C1->new;
ok !$pp->can('attr');

# Instantiate 2 ojects of the same class
{
    my $x = B1->new;
    my $y = B1->new;
    $x->foo->{test} = 'present';
    is $y->foo->{test}, undef;
}

done_testing;
