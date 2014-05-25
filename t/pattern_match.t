
use strict;
use warnings;
use v5.10;

use Test::More;
use Kelp::Routes::Pattern;

# No placeholders
_match(
    '/bar',
    yes => {
        '/bar'  => {},
        '/bar/' => {},
    },
    par => {
        '/bar'  => [],
        '/bar/' => [],
    },
);


_match(
    '/:a/?b',
    yes => {
        '/bar/foo' => { a => 'bar', b => 'foo' },
        '/1/2'     => { a => '1', b => '2' },
        '/bar/'    => { a => 'bar' },
        '/bar'     => { a => 'bar' },
    },
    par => {
        '/bar/foo' => [qw/bar foo/],
        '/bar'     => ['bar', undef]
    },
    no  => ['/bar/foo/baz']
);

# Partials
_match(
    '/:a/{?b}ing',
    yes => {
        '/bar/ing'     => { a => 'bar' },
        '/bar/hopping' => { a => 'bar', b => 'hopp' }
    },
    par => {
        '/bar/ing'     => ['bar', undef],
        '/bar/hopping' => ['bar', 'hopp']
    },
    no => [ '/a/b', '/a', '/a/min' ]
);

_match(
    '/:a/{*b}ing/:c',
    yes => {
        '/bar/hop/ping/foo' => { a => 'bar', b => 'hop/p', c => 'foo' },
    },
    par => {
        '/bar/hop/ping/foo' => [qw{bar hop/p foo}]
    }
);

_match(
    '/:a/:b/:c',
    yes => [qw{
        /a/b/c
        /a-a/b-b/c-c
        /12/23/34
        /бар/фу/баз
        /référence/Français/d'œuf
        /რეგიონების/მიხედვით/არსებობს
    }]
);

_match(
    '/:a/:b',
    yes => {
        '/bar/foo' => { a => 'bar', b => 'foo' },
        '/1/2'     => { a => '1', b => '2' },
        '/bar/foo/'=> { a => 'bar', b => 'foo' },
    },
    par => {
        '/bar/foo' => [qw/bar foo/]
    },
    no  => ['/bar', '/foo', '/bar/foo/baz']
);

_match(
    '/{:a}b/{:c}d',
    yes => {
        '/barb/food' => { a => 'bar', c => 'foo' },
        '/bazb/fizd' => { a => 'baz', c => 'fiz' },
        '/1b/4d'     => { a => '1', c => '4' }
    },
    par => {
        '/barb/food' => [qw/bar foo/],
        '/bazb/fizd' => [qw/baz fiz/],
        '/1b/4d'     => [qw/1 4/]
    },
    no  => [qw{/barba/food /baz/mood /bab/mac /b/ad /ab/d /b/d}]
);

_match(
    '/:a/*b/:c',
    yes => {
        '/bar/foo/baz/bat' => { a => 'bar', b => 'foo/baz', c => 'bat' },
        '/12/56/ab/blah' => { a => '12', b => '56/ab', c => 'blah' }
    },
    par => {
        '/bar/foo/baz/bat' => [qw{bar foo/baz bat}],
        '/12/56/ab/blah' => [qw{12 56/ab blah}]
    },
    no  => [qw{
        /bar/bat
    }]
);

_match(
    '/:a/?b/:c',
    yes => {
        '/a/b/c' => { a => 'a', b => 'b', c => 'c' },
        '/a/c'   => { a => 'a', c => 'c' },
        '/a/c/'  => { a => 'a', c => 'c' }
    },
    par => {
        '/a/b/c' => [qw/a b c/],
        '/a/c'   => ['a', undef, 'c']
    },
    no => [qw{
        /a
        /a/b/c/d
    }]
);

# Defaults
#
_match(
    '/:a/?b',
    yes => {
        '/bar' => { a => 'bar', b => 'boo' },
        '/bar/foo' => { a => 'bar', b => 'foo' }
    },
    par => {
        '/bar' => [qw/bar boo/],
        '/bar/foo' => [qw/bar foo/]
    },
    no => [qw{
        /a/b/c
    }],

    defaults => { b => 'boo' }
);

_match(
    '/:a/?b/:c',
    yes => {
        '/bar/foo' => { a => 'bar', b => 'boo', c => 'foo' },
        '/bar/moo/foo' => { a => 'bar', b => 'moo', c => 'foo' }
    },
    par => {
        '/bar/foo' => [qw/bar boo foo/],
        '/bar/moo/foo' => [qw/bar moo foo/]
    },
    no => [qw{
        /a/b/c/d
        /a
    }],
    defaults => { b => 'boo' }
);

# Check
#
_match(
    '/:a/:b',
    yes => {
        '/123/012012' => {  a => '123', b => '012012' },
    },
    par => {
        '/123/012012' => [qw/123 012012/],
    },
    no => [qw{
        /12/1a
        /1a/12
    }],
    check => { a => '\d+', b => '[0-2]+' }
);

_match(
    '/:a/?b',
    yes => {
        '/123/012012' => {  a => '123', b => '012012' },
        '/123/' => { a => '123' },
        '/123'  => { a => '123' }
    },
    par => {
        '/123/012012' => [qw/123 012012/],
        '/123'  => ['123', undef]
    },
    no => [qw{
        /12/1a
        /1a/12
    }],
    check => { a => '\d+', b => '[0-2]+' }
);

_match(
    '/:a',
    check => { a => '\d{1,3}' },
    yes   => [qw{/1 /12 /123}],
    no    => [qw{/a /ab /abc /1234 /a12}]
);

# Checks and partials
_match(
    '/:a/{?b}ing',
    check => { a => qr/\w{3}/, b => qr/\d{1,3}/ },
    yes   => {
        '/bar/ing'    => { a => 'bar' },
        '/bar/123ing' => { a => 'bar', b => '123' }
    },
    par => {
        '/bar/ing'    => [ 'bar', undef ],
        '/bar/123ing' => [ 'bar', '123' ]
    },
    no => [ '/a/b', '/a', '/a/min', '/a/1234ing' ]
);

_match(
    '/:a/*c',
    check => { a => qr/[^0-9]+/, c => qr/\d{1,2}/ },
    yes => {
        '/abc/69' => { a => 'abc', c => '69' }
    },
    par => {
        '/abc/69' => [qw/abc 69/]
    },
    no => [
        '/123/123',
        '/0/0',
        '/12/a2'
    ]
);

# Regexp instead of pattern
_match(
    qr{/([a-z]+)/([a-z]+)$},
    no  => [qw{/12/12 /123/abc /abc/123}],
    yes => [qw{/abc/a /a/b /a/abc}],
    par => {
        '/abc/a' => [qw{abc a}],
        '/a/b'   => [qw{a b}],
        '/a/abc' => [qw{a abc}],
    }
);

_match(
    qr{/([a-z]+)/?([a-z]*)$},
    no  => [qw{/123 /abc/123}],
    yes => [qw{/abc/def /abc}],
    par => {
        '/abc/def' => [qw/abc def/],
        '/abc'     => [ 'abc', undef ],
    }
);

_match(
    qr{/(\d{1,3})$},
    no  => [ '/abc', '/ab2', '/1234', '/123a' ],
    yes => [qw{/1 /12 /123}],
    par => {
        '/1'   => ['1'],
        '/12'  => ['12'],
        '/123' => ['123']
    }
);

# Method
{
    my $p = Kelp::Routes::Pattern->new( pattern => '/a', via => 'POST' );
    ok $p->match('/a', 'POST');
    ok !$p->match('/a', 'GET');
    ok !$p->match('/a');
}

# no method
{
    my $p = Kelp::Routes::Pattern->new( pattern => '/a' );
    ok $p->match('/a', 'POST');
    ok $p->match('/a', 'GET');
    ok $p->match('/a');
}

done_testing;

sub _match {
    my ( $pattern, %args ) = @_;

    my $yes = delete $args{yes};
    my $par = delete $args{par};
    my $no  = delete $args{no};

    my $p = Kelp::Routes::Pattern->new( pattern => $pattern, %args );
    note "Trying: " . $p->pattern . " -> " . $p->regex;

    if ($yes) {
        my @arr = ref $yes eq 'HASH' ? keys %$yes : @$yes;
        for my $path (@arr) {
            ok $p->match($path), "match: $path";
            if ( ref $yes eq 'HASH' ) {
                is_deeply $p->named, $yes->{$path}, "$path placeholders ok"
                  or diag explain $p->named;
            }
            if ( $par && $par->{$path} ) {
                is_deeply $p->param, $par->{$path}, "$path param ok"
                  or diag caller;
            }
        }
    }

    if ($no) {
        ok !$p->match($_), "no match: $_" for (@$no);
    }
}
