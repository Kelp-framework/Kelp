package Kelp::Routes::Pattern;

use Carp;

use Kelp::Base;

attr pattern  => sub { die "pattern is required" };
attr via      => undef;
attr name     => sub { $_[0]->pattern };
attr check    => sub { {} };
attr defaults => sub { {} };
attr bridge   => 0;
attr regex    => sub { $_[0]->_build_regex };
attr named    => sub { {} };
attr param    => sub { [] };
attr to       => undef;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{_tokens} = [];
    $self->regex;    # Compile the regex
    return $self;
}

sub _rep_regex {
    my ( $self, $char, $switch, $token ) = @_;

    push @{$self->{_tokens}}, $token;

    my ( $a, $b, $r ) = ( "(?<$token>", ')', undef );
    for ($switch) {
        if ( $_ eq ':' || $_ eq '?' ) {
            $r = $a . ( $self->check->{$token} // '[^\/]+' ) . $b
        }
        if ( $_ eq '*' ) {
            $r = $a . '.+' . $b
        }
    }

    $char = $char . '?' if $char eq '/' && $switch eq '?';
    $r .= '?' if $switch eq '?';

    return $char . $r;
}

sub _build_regex {
    my $self = shift;
    return $self->pattern if ref $self->pattern eq 'Regexp';

    my $PAT = '(.?)([:*?])(\w+)';
    my $pattern =  $self->pattern;

    # Curly braces and brackets are only used for separation.
    # We replace all of them with \0, then convert the pattern
    # into a regular expression. This way if the regular expression
    # contains curlies, they won't be removed.
    $pattern =~ s/[{}]/\0/g;
    $pattern =~ s{$PAT}{$self->_rep_regex($1, $2, $3)}eg;
    $pattern =~ s/\0//g;
    $pattern .= '/?' unless $pattern =~ m{/$};
    $pattern .= '$' unless $self->bridge;

    return qr{^$pattern};
}

sub _rep_build {
    my ( $self, $switch, $token, %args ) = @_;
    my $rep = $args{$token} // $self->defaults->{$token} // '';
    if ($switch ne '?' && !$rep) {
        return '{?' . $token . '}';
    }
    my $check = $self->check->{$token};
    if ( $check && $args{$token} !~ $check ) {
        return '{!' . $token . '}';
    }
    return $rep;
}

sub build {
    my ( $self, %args ) = @_;

    my $pattern = $self->pattern;
    if ( ref $pattern eq 'Regexp' ) {
        carp "Can't build a path for regular expressions";
        return;
    }

    my $PAT = '([:*?])(\w+)';
    $pattern =~ s/{?$PAT}?/$self->_rep_build($1, $2, %args)/eg;
    if ($pattern =~ /{([!?])(\w+)}/) {
        carp $1 eq '!'
            ? "Field $2 doesn't match checks"
            : "Default value for field $2 is missing";
        return undef;
    }
    return $pattern;
}

sub match {
    my ( $self, $path, $method ) = @_;
    return 0 if ( $self->via && $self->via ne ( $method // '' ) );
    return 0 unless my @matched = $path =~ $self->regex;

    @matched = () unless $#+; # were there any captures? see perlvar @+

    # Initialize the named parameters hash and its default values
    my %named = map { $_ => $+{$_} } keys %+;
    for ( keys %{ $self->defaults } ) {
        $named{$_} = $self->defaults->{$_} unless exists $named{$_};
    }
    $self->named( \%named );

    # Initialize the param array, containing the values of the
    # named placeholders in the order they appear in the regex.
    if ( my @tokens = @{ $self->{_tokens} } ) {
        $self->param( [ map { $named{$_} } @tokens ] );
    }
    else {
        $self->param( [ map { $_ eq '' ? undef : $_ } @matched] );
    }

    return 1;
}

1;

__END__

=head1 NAME

Kelp::Routes::Pattern - Route patterns for Kelp routes

=head1 SYNOPSIS

    my $p = Kelp::Routes::Pattern->new( pattern => '/:name/:place' );
    if ( $p->match('/james/london') ) {
        %named = %{ $p->named };    # ( name => 'james', place => 'london' )
        @param = @{ $p->param };    # ( 'james', 'london' )
    }

=head1 DESCRIPTION

This module is needed by L<Kelp::Routes>. It provides matching for
individual route patterns, returning the named placeholders in a hash and an
array.

=head1 ATTRIBUTES

=head2 pattern

The pattern to match against. Each pattern is a string, which may contain named
placeholders. For more information on the types and use of placeholders, look at
L<Kelp::Routes/PLACEHOLDERS>.

    my $p = Kelp::Routes::Patters->new( pattern => '/:id/*other' );
    ...
    $p->match('/4/something-else');    # True

=head2 via

Specifies an HTTP method to be matched by the route.

    my $p = Kelp::Routes::Patters->new(
        pattern => '/:id/*other',
        via     => 'PUT'
    );

    $p->match('/4/something-else', 'GET');    # False. Only PUT allowed.

=head2 name

You are encouraged to give each route a name, so you can look it up later when
you build a URL for it.

    my $p = Kelp::Routes::Patters->new(
        pattern => '/:id/*other',
        name    => 'other_id'
    );
    ...

    say $p->build( 'other_id', id => '100', other => 'something-else' );
    # Prints '/100/something-else'

If no name is provided for the route, the C<pattern> is used.

=head2 check

A hashref with placeholder names as keys and regular expressions as values. It
is used to match the values of the placeholders against the provided regular
expressions.

    my $p = Kelp::Routes::Patters->new(
        pattern => '/:id/*other',
        check   => { id => qr/\d+/ }    # id may only be a didgit
    );

    $p->match('/4/other');    # True
    $p->match('/q/other');    # False

Note: Do not add C<^> at the beginning or C<$> at the end of the regular
expressions, because they are merged into a bigger regex.

=head2 defaults

A hashref with placeholder defaults. This only applies to optional placeholders,
or those prefixed with a question mark. If a default value is provided for any
of them, it will be used in case the placeholder value is missing.

    my $p = Kelp::Routes::Patters->new(
        pattern  => '/:id/?other',
        defaults => { other => 'info' }
    );

    $p->match('/100');
    # $p->named will contain { id => 100, other => 'info' }

    $p->match('/100/delete');
    # $p->named will contain { id => 100, other => 'delete' }

=head2 bridge

A True/False value. Specifies if the route is a bridge. For more information
about bridges, please see L<Kelp::Routes/BRIDGES>

=head2 regex

We recommend that you stick to using patterns, because they are simpler and
easier to read, but if you need to match a really complicated route, then
you can use a regular expression.

    my $p = Kelp::Routes::Patters->new( regex => qr{^(\d+)/(\d+)$} );
    $p->match('/100/200');  # True. $p->param will be [ 100, 200 ]

After matching, the L</param> array will be initialized with the values of the
captures in the order they appear in the regex.
If you used a regex with named captures, then a hashref L</named> will also be
initialized with the names and values of the named placeholders. In other words,
this hash will be a permanent copy of the C<%+> built-in hash.

    my $p = Kelp::Routes::Patters->new( regex => qr{^(?<id>\d+)/(?<line>\d+)$} );
    $p->match('/100/200');  # True.
                            # $p->param will be [ 100, 200 ]
                            # $p->named will be { id => 100, line => 200 }

If C<regex> is not explicitly given a value it will be built from the
C<pattern>.

=head2 named

A hashref which will be initialized by the L</match> function. After matching,
it will contain placeholder names and values for the matched route.

=head2 param

An arrayref, which will be initialized by the L</match> function. After matching,
it will contain all placeholder values in the order they were specified in the
pattern.

=head2 to

Specifies the route destination. See examples in L<Kelp::Routes>.

=head1 METHODS

=head2 match

C<match( $path, $method )>

Matches an already initialized route against a path and http method. If the match
was successful, this sub will return a true value and the L</named> and L</param>
attributes will be initialized with the names and values of the matched placeholders.

=head2 build
C<build( %args )>

Builds a URL from a pattern.

    my $p = Kelp::Routes::Patters->new( pattern  => '/:id/:line/:row' );
    $p->build( id => 100, line => 5, row => 8 ); # Returns '/100/5/8'

=head1 ACKNOWLEDGEMENTS

This module was inspired by L<Routes::Tiny>.

The concept of bridges was borrowed from L<Mojolicious>

=cut
