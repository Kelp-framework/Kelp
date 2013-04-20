package A; sub b{} 1;
package Ab; sub c{} 1;

package main;
use strict;
use warnings;

use Test::More;
use Kelp::Routes;

my $r = Kelp::Routes->new;

$r->add( '/a' => { to => 'a', name => 'a' } );
$r->add( '/b' => { to => 'b', name => 'b' } );
$r->add( '/a/b' => { to => 'a#b', name => 'ab' } );
$r->add( '/a/b/c' => 'ab#c');

is $r->url('noname'), 'noname';
is $r->url('a'), '/a';
is $r->url('b'), '/b';
is $r->url('ab'), '/a/b';

$r->clear;
$r->add('/:a/:b', { to => 'a', name => 'a' });
$r->add('/:a/?b', { to => 'b', name => 'b', defaults => { b => 'foo' } });

is $r->url(qw/a a bar b foo/), '/bar/foo';
is $r->url(qw/b a bar b moo/), '/bar/moo';
is $r->url(qw/b a bar/), '/bar/foo';

done_testing;

