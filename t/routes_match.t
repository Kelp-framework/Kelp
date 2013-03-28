
use strict;
use warnings;

use Test::More;
use Kelp::Routes;

my $r = Kelp::Routes->new;

# Simple
{
    $r->add( '/:a/:b' => 'a#b' );
    is_deeply $r->match($_), [] for ('/a', '', '/a/b/c', 'a');
    is_deeply _d($r->match('/a/b'), 'to'), [ { to => 'A::b' } ];
    is_deeply _d($r->match('/a/b', 'GET'), 'to'), [ { to => 'A::b' } ];
    is_deeply _d($r->match('/a/b', 'PUT'), 'to'), [ { to => 'A::b' } ];
    is_deeply _d($r->match('/a/b', 'POST'), 'to'), [ { to => 'A::b' } ];
    is_deeply _d($r->match('/a/b', 'DELETE'), 'to'), [ { to => 'A::b' } ];
}

# With method
{
    $r->clear;
    $r->add( [ POST => '/:a'] => 'a' );
    is_deeply $r->match($_), [] for ('/a', '', '/a/b', 'a');
    is_deeply _d($r->match('/a', 'POST'), 'to'), [ { to => 'a' } ];
    is_deeply _d($r->match('/a', 'GET'), 'to'), [];
}

# Another method
{
    $r->clear;
    $r->add( [ GET => '/:a'] => 'a' );
    is_deeply $r->match($_), [] for ('/a', '', '/a/b', 'a');
    is_deeply _d($r->match('/a', 'POST'), 'to'), [  ];
    is_deeply _d($r->match('/a', 'GET'), 'to'), [{ to => 'a' }];
}

# Similar routes with checks
{
    $r->clear;
    $r->add( '/:a/:b' => 'a' );
    $r->add( '/:a/:b' => { to => 'b', check => { b => '\d+' } } );
    $r->add( '/:a/:b' => { to => 'c', check => { a => '\d+' } } );
    is_deeply _d($r->match('/aa/bb'), 'to'), [{ to => 'a' }];
    is_deeply _d($r->match('/aa/22'), 'to'), [{ to => 'a' }, { to => 'b' }];
    is_deeply _d($r->match('/11/bb'), 'to'), [{ to => 'a' }, { to => 'c' }];
    is_deeply _d($r->match('/11/22'), 'to'), [{ to => 'a' }, { to => 'b' }, { to => 'c' }];
}

# Different routes (same beginning)
{
    $r->clear;
    $r->add( '/:a' => 'a' );
    $r->add( '/:a/:b' => { to => 'b', check => { b => '\d' } } );
    $r->add( '/:a/:b/:c' => 'c' );

    is_deeply _d($r->match('/a'), 'to'), [{ to => 'a' }];
    is_deeply _d($r->match('/a/2'), 'to'), [{ to => 'b' }];
    is_deeply _d($r->match('/a/b'), 'to'), [];
    is_deeply _d($r->match('/a/b/c'), 'to'), [{ to => 'c' }];
}

# Bridges
{
    $r->clear;
    $r->add( '/:a' => { to => 'a', bridge => 1 } );
    $r->add( '/:a/:b' => { to => 'b', check => { b => '\d' } } );
    $r->add( '/:a/:b/:c' => 'c' );

    is_deeply _d($r->match('/a'), 'to'), [{ to => 'a' }];
    is_deeply _d($r->match('/a/2'), 'to'), [{to => 'a'}, { to => 'b' }];
    is_deeply _d($r->match('/a/b'), 'to'), [{to => 'a'}];
    is_deeply _d($r->match('/a/b/c'), 'to'), [{to => 'a'}, { to => 'c' }];
}

# Cache
{
    $r->clear;
    $r->add('/a', 'a');
    my $m = $r->match('/a');
    is_deeply $m, $r->cache->{'/a:'};

    $m = $r->match('/a', 'POST');
    is_deeply $m, $r->cache->{'/a:POST'};

    $r->add('/a/b', { to => 'ab', bridge => 1 });
    $m = $r->match('/a/b');
    is_deeply $m, $r->cache->{'/a/b:'};
    $r->add('/a/b/c', 'abc');
    my $n = $r->match('/a/b/c');
    is_deeply $n, $r->cache->{'/a/b/c:'};
}

done_testing;

sub _d {
    my ( $m, @fields ) = @_;
    my @o = ();
    for my $route ( @$m ) {
        my @a = scalar(@fields) ? @fields : keys %{$route};
        my %h = ();
        for my $k ( @a ) {
            $h{$k} = $route->{$k} if ( defined $route->{$k} );
        }
        push @o, \%h;
    }
    return \@o;
}
