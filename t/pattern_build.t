
use strict;
use warnings;
use v5.10;

use Test::More;
use Test::Exception;
use Kelp::Routes::Pattern;

{
    my $p = Kelp::Routes::Pattern->new(pattern => '/:a/:b');
    is $p->build(a => 1, b => 2), '/1/2';
    is $p->build(a => 'bar', b => 'foo'), '/bar/foo';
    dies_ok { $p->build(a => 'bar') };
    dies_ok { $p->build(b => 'bar') };
    dies_ok { $p->build() };
}

{
    my $p = Kelp::Routes::Pattern->new(pattern => '/:a/?b');
    is $p->build(a => 1, b => 2), '/1/2';
    is $p->build(a => 'bar', b => 'foo'), '/bar/foo';
    is $p->build(a => 'bar'), '/bar/';
    dies_ok { $p->build(b => 'bar') };
}

# Checks
{
    my $p = Kelp::Routes::Pattern->new(
        pattern => '/:a/:b',
        check => {a => '\d+', b => '[a-z]+'}
    );
    is $p->build(a => 1, b => 'a'), '/1/a';
    dies_ok { $p->build(a => 1, b => 2) };
    dies_ok { $p->build(a => 'a', b => 'b') };
}

# Defaults
{
    my $p = Kelp::Routes::Pattern->new(
        pattern => '/:a/?b',
        defaults => {b => 'foo'}
    );
    is $p->build(a => 'bar', b => 'baz'), '/bar/baz';
    is $p->build(a => 'bar'), '/bar/foo';
    dies_ok { $p->build(b => 'bar') };
}

{
    my $p = Kelp::Routes::Pattern->new(
        pattern => '/?a/:b',
        defaults => {a => 'bar'}
    );
    is $p->build(a => 'foo', b => 'baz'), '/foo/baz';
    is $p->build(b => 'bar'), '/bar/bar';
    dies_ok { $p->build(a => 'foo') };
}

{
    my $p = Kelp::Routes::Pattern->new(
        pattern => '/:a/>b',
        defaults => {b => 'bar/baz'}
    );
    is $p->build(a => 'bar', b => 'baz'), '/bar/baz';
    is $p->build(a => 'foo'), '/foo/bar/baz';
    dies_ok { $p->build(b => 'bar') };
}

# Captures
{
    my $p = Kelp::Routes::Pattern->new(pattern => '/{:a}ing/{:b}ing');
    is $p->build(a => 'go', b => 'walk'), '/going/walking';
    dies_ok { $p->build(a => 'go') };
}

# Conditional captures
{
    my $p = Kelp::Routes::Pattern->new(
        pattern => '/{:a}ing/{?b}ing',
        defaults => {b => 'fart'}
    );
    is $p->build(a => 'sleep'), '/sleeping/farting';
    dies_ok { $p->build(b => 'talk') };
}

{
    my $p = Kelp::Routes::Pattern->new(pattern => '/{:a}ing/{?b}ing');
    is $p->build(a => 'sleep'), '/sleeping/ing';
    dies_ok { $p->build(b => 'talk') };
}

# Globs
{
    my $p = Kelp::Routes::Pattern->new(pattern => '/*a/:b');
    is $p->build(a => 'bar', b => 'foo'), '/bar/foo';
    is $p->build(a => 'bar/bat', b => 'foo'), '/bar/bat/foo';
    dies_ok { $p->build(b => 'foo') };
    dies_ok { $p->build(a => 'foo') };
}

{
    my $p = Kelp::Routes::Pattern->new(pattern => '/a/*/*b');
    is $p->build('*' => 'hello', b => 5), '/a/hello/5';
    is $p->build('*' => 'b/c', b => 'd'), '/a/b/c/d';
    dies_ok { $p->build(b => '??') };
    dies_ok { $p->build('*' => 'foo') };
}

# Slurpy
{
    my $p = Kelp::Routes::Pattern->new(pattern => '/:a/>b');
    is $p->build(a => 'bar', b => 'foo'), '/bar/foo';
    is $p->build(a => 'bar', b => 'bat/foo'), '/bar/bat/foo';
    dies_ok { $p->build(b => 'foo') };
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

# Regex pattern cannot be built
{
    my $p = Kelp::Routes::Pattern->new(pattern => qr{^/hello});
    dies_ok { $p->build() };
}

done_testing;

