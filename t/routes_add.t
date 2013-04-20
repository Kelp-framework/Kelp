package A; sub b{} 1;
package Bar; sub foo{} 1;
package Bar::Foo; sub baz{} 1;

use strict;
use warnings;

BEGIN {
    my $DOWARN = 0;
    $SIG{'__WARN__'} = sub { warn $_[0] if $DOWARN }
}

use Test::More;
use Kelp::Routes;

my $r = Kelp::Routes->new;


# Basic
#
{
    $r->add( '/a' => 'a#b' );
    is_deeply _d( $r, qw/pattern to/ ), [
        {
            pattern => '/a',
            to      => 'A::b'
        }
      ];
}

# Via method
#
{
    $r->clear;
    $r->add( [ POST => '/a' ] => 'a#b' );
    is_deeply _d( $r, qw/via pattern to/ ), [
        {
            via     => 'POST',
            pattern => '/a',
            to      => 'A::b'
        }
      ];
}

# Odd method
#
{
    $r->clear;
    $r->add( [ MOST => '/a' ] => 'a#b' );
    is_deeply _d( $r, qw/via pattern to/ ), [
        {
            via     => 'MOST',
            pattern => '/a',
            to      => 'A::b'
        }
    ];
}

# Sub
#
{
    $r->clear;
    $r->add( '/a' => sub { } );
    is ref( $r->routes->[0]->to ), 'CODE';
}

# Not hash
#
{
    $r->clear;
    $r->add( '/a' => [] );
    is_deeply $r->routes, [];
}

# Weird key
#
{
    $r->clear;
    $r->add( { a => 1 }, 'a#b' );
    is_deeply $r->routes, [];

    $r->add( [ POST => { a => 1 } ], 'a#b' );
    is_deeply $r->routes, [];
}

# Missing destination
#
{
    $r->clear;
    $r->add( '/a' => { name => 'a' } );
    is_deeply $r->routes, [];
}

# Key trumps via in the value
{
    $r->clear;
    $r->add([POST => '/a'] => { to => 'a', via => 'PUT' });
    is_deeply _d($r, qw/via/), [{ via => 'POST' }];
}

# Regex
#
{
    $r->clear;
    my $re = qr{^/a/(\w+)$};
    $r->add( $re, 'bar#foo' );
    is_deeply _d($r, qw/pattern/), [{
        pattern => $re
    }];
}

# Hash
#
{
    $r->clear;
    my $hash = {
        name  => 'james',
        check => { a => '\d' },
        to    => 'bar#foo'
    };
    $r->add( '/:a' => $hash );
    is_deeply _d( $r, qw/name check to/ ), [
        {
            name  => 'james',
            check => { a => '\d' },
            to    => 'Bar::foo'
        }
    ];
}

# Base
#
{
    $r->clear;
    $r->base('Bar');
    $r->add('/a' => 'foo#baz');
    is_deeply _d( $r, qw/to/ ), [
        {
            to    => 'Bar::Foo::baz'
        }
    ];
    $r->base('');
}

# Tree
#
{

    # Tree not ARRAY
    $r->clear;
    $r->add('/user' => {
        tree => { a => 1, b => 2}
    });
    is_deeply $r->routes, [];

    # Tree no name
    $r->clear;
    $r->add('/a' => {
        to => 'a',
        tree => [
            '/b' => { name => 'b', to => 'a#b' },
            '/c' => 'a#c'
        ]
    });
    is_deeply _d($r, 'name'), [ {}, { name => 'b' }, {} ];


    # Good tree
    $r->clear;
    $r->add(
        '/user' => {
            name => 'user',
            to   => 'bar#user',
            tree => [
                '/id'   => { to => 'bar#id',   name => 'id' },
                '/edit' => { to => 'bar#edit', name => 'edit' },
                [ DELETE => '/id' ] => { to => 'bar#del' => name => 'delete' },
                '/change' => {
                    to   => 'bar#change',
                    name => 'change',
                    tree => [
                        '/name' => { to => 'bar#change_name', name => 'name' },
                        [ PUT  => '/email' ] => { to => 'bar#change_email', name => 'email' }
                    ]
                }
            ]
        }
    );

    is_deeply _d( $r, qw/pattern name to via/ ), [
        {
            pattern => '/user',
            name    => 'user',
            to      => 'Bar::user',
        }, {
            pattern => '/user/id',
            name    => 'user_id',
            to      => 'Bar::id',
        }, {
            pattern => '/user/edit',
            name    => 'user_edit',
            to      => 'Bar::edit',
        }, {
            pattern => '/user/id',
            name    => 'user_delete',
            to      => 'Bar::del',
            via     => 'DELETE'
        }, {
            pattern => '/user/change',
            name    => 'user_change',
            to      => 'Bar::change'
        }, {
            pattern => '/user/change/name',
            name    => 'user_change_name',
            to      => 'Bar::change_name'
        }, {
            pattern => '/user/change/email',
            name    => 'user_change_email',
            to      => 'Bar::change_email',
            via     => 'PUT'
        }
      ];
}


sub _d {
    my ( $r, @fields ) = @_;
    my @o = ();
    for my $route ( @{ $r->routes } ) {
        my @a = scalar(@fields) ? @fields : keys %{$route};
        my %h = ();
        for my $k ( @a ) {
            $h{$k} = $route->{$k} if ( defined $route->{$k} );
        }
        push @o, \%h;
    }
    return \@o;
}


done_testing;


