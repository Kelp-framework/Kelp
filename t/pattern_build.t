
use strict;
use warnings;
use v5.10;

BEGIN {
    my $DOWARN = 0;
    $SIG{'__WARN__'} = sub { warn $_[0] if $DOWARN }
}

use Test::More;
use Kelp::Routes::Pattern;

{
    my $p = Kelp::Routes::Pattern->new(pattern => '/:a/:b');
    is $p->build(a => 1, b => 2), '/1/2';
    is $p->build(a => 'bar', b => 'foo'), '/bar/foo';
    is $p->build(a => 'bar'), undef;
    is $p->build(b => 'bar'), undef;
    is $p->build(), undef;
}

{
    my $p = Kelp::Routes::Pattern->new(pattern => '/:a/?b');
    is $p->build(a => 1, b => 2), '/1/2';
    is $p->build(a => 'bar', b => 'foo'), '/bar/foo';
    is $p->build(a => 'bar'), '/bar/';
    is $p->build(b => 'bar'), undef;
}

# Checks
{
    my $p = Kelp::Routes::Pattern->new(
        pattern => '/:a/:b',
        check => {a => '\d+', b => '[a-z]+'}
    );
    is $p->build(a => 1, b => 'a'), '/1/a';
    is $p->build(a => 1, b => 2), undef;
    is $p->build(a => 'a', b => 'b'), undef;
}

# Defaults
{
    my $p = Kelp::Routes::Pattern->new(
        pattern => '/:a/?b',
        defaults => {b => 'foo'}
    );
    is $p->build(a => 'bar', b => 'baz'), '/bar/baz';
    is $p->build(a => 'bar'), '/bar/foo';
    is $p->build(b => 'bar'), undef;
}

{
    my $p = Kelp::Routes::Pattern->new(
        pattern => '/?a/:b',
        defaults => {a => 'bar'}
    );
    is $p->build(a => 'foo', b => 'baz'), '/foo/baz';
    is $p->build(b => 'bar'), '/bar/bar';
    is $p->build(a => 'foo'), undef;
}

{
    my $p = Kelp::Routes::Pattern->new(
        pattern => '/:a/>b',
        defaults => {b => 'bar/baz'}
    );
    is $p->build(a => 'bar', b => 'baz'), '/bar/baz';
    is $p->build(a => 'foo'), '/foo/bar/baz';
    is $p->build(b => 'bar'), undef;
}

# Captures
{
    my $p = Kelp::Routes::Pattern->new(pattern => '/{:a}ing/{:b}ing');
    is $p->build(a => 'go', b => 'walk'), '/going/walking';
    is $p->build(a => 'go'), undef;
}

# Conditional captures
{
    my $p = Kelp::Routes::Pattern->new(
        pattern => '/{:a}ing/{?b}ing',
        defaults => {b => 'fart'}
    );
    is $p->build(a => 'sleep'), '/sleeping/farting';
    is $p->build(b => 'talk'), undef;
}

{
    my $p = Kelp::Routes::Pattern->new(pattern => '/{:a}ing/{?b}ing');
    is $p->build(a => 'sleep'), '/sleeping/ing';
    is $p->build(b => 'talk'), undef;
}

# Globs
{
    my $p = Kelp::Routes::Pattern->new(pattern => '/*a/:b');
    is $p->build(a => 'bar', b => 'foo'), '/bar/foo';
    is $p->build(a => 'bar/bat', b => 'foo'), '/bar/bat/foo';
    is $p->build(b => 'foo'), undef;
    is $p->build(a => 'foo'), undef;
}

{
    my $p = Kelp::Routes::Pattern->new(pattern => '/a/*/*b');
    is $p->build('*' => 'hello', b => 5), '/a/hello/5';
    is $p->build('*' => 'b/c', b => 'd'), '/a/b/c/d';
    is $p->build(b => '??'), undef;
    is $p->build('*' => 'foo'), undef;
}

# Slurpy
{
    my $p = Kelp::Routes::Pattern->new(pattern => '/:a/>b');
    is $p->build(a => 'bar', b => 'foo'), '/bar/foo';
    is $p->build(a => 'bar', b => 'bat/foo'), '/bar/bat/foo';
    is $p->build(b => 'foo'), undef;
    is $p->build(a => 'foo'), '/foo/';
}

{
    my $p = Kelp::Routes::Pattern->new(pattern => '/a/>');
    is $p->build('>' => 'hello'), '/a/hello';
    is $p->build('>' => 'b/c'), '/a/b/c';
    is $p->build(), '/a/';
}

# Two unnamed items
{
    my $p = Kelp::Routes::Pattern->new(pattern => '/hello/*/>');
    is $p->build('*' => 'kelp', '>' => 'world'), '/hello/kelp/world';
}

done_testing;

