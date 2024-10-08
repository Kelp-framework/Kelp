package A;
sub b { }
sub c { }
sub d { }

1;

package main;
use strict;
use warnings;

use Test::More;
use Kelp::Routes;

my $r = Kelp::Routes->new;

# Simple
{
    $r->add('/:a/:b' => 'a#b');
    is_deeply $r->match($_), [] for ('/a', '', '/a/b/c', 'a');
    is_deeply _d($r->match('/a/b'), 'to'), [{to => 'A::b'}];
    is_deeply _d($r->match('/a/b', 'GET'), 'to'), [{to => 'A::b'}];
    is_deeply _d($r->match('/a/b', 'PUT'), 'to'), [{to => 'A::b'}];
    is_deeply _d($r->match('/a/b', 'POST'), 'to'), [{to => 'A::b'}];
    is_deeply _d($r->match('/a/b', 'DELETE'), 'to'), [{to => 'A::b'}];
}

# With method
{
    $r->clear;
    $r->add([POST => '/:a'] => 'a#b');
    is_deeply $r->match($_), [] for ('/a', '', '/a/b', 'a');
    is_deeply _d($r->match('/a', 'POST'), 'to'), [{to => 'A::b'}];
    is_deeply _d($r->match('/a', 'GET'), 'to'), [];
}

# Another method
{
    $r->clear;
    $r->add([GET => '/:a'] => 'a#c');
    is_deeply $r->match($_), [] for ('/a', '', '/a/b', 'a');
    is_deeply _d($r->match('/a', 'POST'), 'to'), [];
    is_deeply _d($r->match('/a', 'GET'), 'to'), [{to => 'A::c'}];
}

# Similar routes with checks
{
    $r->clear;
    $r->add('/:a/:b' => {to => 'a#b', order => 10});
    $r->add('/:a/:b' => {to => 'a#c', check => {b => '\d+'}});
    $r->add('/:a/:b' => {to => 'a#d', check => {a => '\d+'}, order => -1});
    is_deeply _d($r->match('/aa/bb'), 'to'), [{to => 'A::b'}];
    is_deeply _d($r->match('/aa/22'), 'to'), [{to => 'A::c'}, {to => 'A::b'}];
    is_deeply _d($r->match('/11/bb'), 'to'), [{to => 'A::d'}, {to => 'A::b'}];
    is_deeply _d($r->match('/11/22'), 'to'), [{to => 'A::d'}, {to => 'A::c'}, {to => 'A::b'}];
}

# Different routes (same beginning)
{
    $r->clear;
    $r->add('/:a' => 'a#b');
    $r->add('/:a/:b' => {to => 'a#c', check => {b => '\d'}});
    $r->add('/:a/:b/:c' => 'a#d');

    is_deeply _d($r->match('/a'), 'to'), [{to => 'A::b'}];
    is_deeply _d($r->match('/a/2'), 'to'), [{to => 'A::c'}];
    is_deeply _d($r->match('/a/b'), 'to'), [];
    is_deeply _d($r->match('/a/b/c'), 'to'), [{to => 'A::d'}];
}

# Bridges
{
    $r->clear;
    $r->add('/:a' => {to => 'a#b', bridge => 1});
    $r->add('/:a/:b' => {to => 'a#c', check => {b => '\d'}});
    $r->add('/:a/:b/:c' => 'a#d');

    is_deeply _d($r->match('/a'), 'to'), [{to => 'A::b'}];
    is_deeply _d($r->match('/a/2'), 'to'), [{to => 'A::b'}, {to => 'A::c'}];
    is_deeply _d($r->match('/a/b'), 'to'), [{to => 'A::b'}];
    is_deeply _d($r->match('/a/b/c'), 'to'), [{to => 'A::b'}, {to => 'A::d'}];
}

# Bridges - root
{
    $r->clear;
    $r->add('' => {to => 'a#b', bridge => 1});
    $r->add('/' => {to => 'a#c', bridge => 1});

    is_deeply _d($r->match('/'), 'to'), [{to => 'A::b'}, {to => 'A::c'}];
    is_deeply _d($r->match('/test'), 'to'), [{to => 'A::b'}, {to => 'A::c'}];
}

# Bridges - trailing slashes
{
    $r->clear;
    $r->add('/test' => {to => 'a#b', bridge => 1});
    $r->add('/test/' => {to => 'a#c', bridge => 1});

    is_deeply _d($r->match('/test'), 'to'), [{to => 'A::b'}];
    is_deeply _d($r->match('/test/'), 'to'), [{to => 'A::b'}, {to => 'A::c'}];
    is_deeply _d($r->match('/test/more'), 'to'), [{to => 'A::b'}, {to => 'A::c'}];
    is_deeply _d($r->match('/test/more/stuff'), 'to'), [{to => 'A::b'}, {to => 'A::c'}];
}

# Bridges - no longer url parts than defined
{
    $r->clear;
    $r->add('/test' => {to => 'a#b', bridge => 1});
    $r->add('/test' => 'a#c');
    $r->add('/test/a' => 'a#d');

    is_deeply _d($r->match('/testing'), 'to'), [];
    is_deeply _d($r->match('/test'), 'to'), [{to => 'A::b'}, {to => 'A::c'}];
    is_deeply _d($r->match('/test/'), 'to'), [{to => 'A::b'}, {to => 'A::c'}];
    is_deeply _d($r->match('/test/a'), 'to'), [{to => 'A::b'}, {to => 'A::d'}];
    is_deeply _d($r->match('/test/aa'), 'to'), [{to => 'A::b'}];
}

# Cache
{
    $r->clear;
    $r->add('/a', 'a#b');
    my $m = $r->match('/a');
    is_deeply $m, $r->cache->get('/a:');

    $m = $r->match('/a', 'POST');
    is_deeply $m, $r->cache->get('/a:POST');

    $r->add('/a/b', {to => 'a#c', bridge => 1});
    $m = $r->match('/a/b');
    is_deeply $m, $r->cache->get('/a/b:');
    $r->add('/a/b/c', 'a#d');
    my $n = $r->match('/a/b/c');
    is_deeply $n, $r->cache->get('/a/b/c:');
}

# Regex in routes is forbidden
{
    $r->clear;
    $r->add('/a.html', 'a#b');

    is_deeply _d($r->match('/a.html'), 'to'), [{to => 'A::b'}];
    is_deeply _d($r->match('/aahtml'), 'to'), [];

    $r->add('/b+', 'a#b');
    is_deeply _d($r->match('/bbbbbb'), 'to'), [];
}

done_testing;

sub _d
{
    my ($m, @fields) = @_;
    my @o = ();
    for my $route (@$m) {
        my @a = scalar(@fields) ? @fields : keys %{$route};
        my %h = ();
        for my $k (@a) {
            $h{$k} = $route->{$k} if (defined $route->{$k});
        }
        push @o, \%h;
    }
    return \@o;
}

