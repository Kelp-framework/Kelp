package Kelp::Routes::Pattern;

use Carp;

use Kelp::Base;

our @CARP_NOT = qw(Kelp::Routes);

attr pattern => sub { die "pattern is required" };
attr via => undef;
attr method => sub { $_[0]->via };
attr has_name => undef;
attr name => sub { $_[0]->pattern };
attr check => sub { {} };
attr defaults => sub { {} };
attr bridge => 0;
attr order => 0;
attr regex => sub { $_[0]->_build_regex };
attr named => sub { {} };
attr param => sub { [] };
attr to => undef;
attr dest => undef;
attr psgi_middleware => undef;

# helpers for matching different types of wildcards
sub __noslash
{
    1 == grep { $_[0] eq $_ } ':', '?';
}

sub __matchall
{
    1 == grep { $_[0] eq $_ } '*', '>';
}

sub __optional
{
    1 == grep { $_[0] eq $_ } '?', '>';
}

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->has_name(defined $self->{name} && length $self->{name});    # remember if pattern was named

    $self->_fix_pattern;
    $self->regex;    # Compile the regex
    return $self;
}

sub _fix_pattern
{
    my ($self) = @_;
    my $pattern = $self->pattern;
    return if ref $pattern;    # only fix non-regex patterns

    # operations performed
    $pattern =~ s{/+}{/}g;

    $self->pattern($pattern);
}

sub _rep_regex
{
    my ($self, $char, $switch, $token) = @_;
    my $qchar = quotemeta $char;
    my $re;

    my $optional = sub {
        return unless __optional($switch);
        $re = "(?:$re)" if $char eq '/';
        $re .= '?';
    };

    # no token - only valid for the wildcard * and slurpy >
    if (!defined $token) {

        # do nothing
        return $char . $switch
            unless __matchall($switch);

        $re = $qchar . '(.+)';
    }
    else {
        push @{$self->{_tokens}}, $token;

        my ($prefix, $suffix) = ("(?<$token>", ')');
        if (__noslash($switch)) {
            $re = $qchar . $prefix . ($self->check->{$token} // '[^\/]+') . $suffix;
        }
        elsif (__matchall($switch)) {
            $re = $qchar . $prefix . ($self->check->{$token} // '.+') . $suffix;
        }
    }

    $optional->();
    push @{$self->{_rep_regex_parts}}, $re;
    return '{}';
}

sub _build_regex
{
    my $self = shift;
    $self->{_tokens} = [];

    return $self->pattern if ref $self->pattern eq 'Regexp';

    my $placeholder_pattern = qr{
        ( [^\0]? ) # preceding char, may change behavior of some placeholders
        ( [:*?>] ) # placeholder sigil
        ( \w+ )?   # placeholder label
    }x;
    my $pattern = $self->pattern;

    # Curly braces and brackets are only used for separation.
    # We replace all of them with \0, then convert the pattern
    # into a regular expression. This way if the regular expression
    # contains curlies, they won't be removed.
    $pattern =~ s/[{}]/\0/g;

    $self->{_rep_regex_parts} = [];
    $pattern =~ s{$placeholder_pattern}{$self->_rep_regex($1, $2, $3)}eg;

    # Now remove all curlies remembered as \0 - We will use curlies again for
    # special behavior in a moment
    $pattern =~ s/\0//g;

    # remember if the pattern has a trailing slash before we quote it
    my $trailing_slash = $pattern =~ m{/$};

    # _rep_regex reused curies for {} placeholders, so we want to split the
    # string by that (and include them in the result by capturing the
    # separator)
    my @parts = split /(\Q{}\E)/, $pattern, -1;

    # If we have a placeholder, replace it with next part. If not, quote it to
    # avoid misusing regex in patterns.
    foreach my $part (@parts) {
        if ($part eq '{}') {
            $part = shift @{$self->{_rep_regex_parts}};
        }
        else {
            $part = quotemeta $part;
        }
    }

    $pattern = join '', @parts;
    if ($self->bridge) {

        # bridge must be followed by a slash or end of string, so that:
        # - /test matches
        # - /test/ matches
        # - /test/something matches
        # - /testsomething does not match
        # if the bridge is already followed by a trailing slash, it's not a
        # concern
        $pattern .= '(?:/|$)' unless $trailing_slash;
    }
    else {

        # regular pattern must end immediately
        $pattern .= quotemeta('/') . '?' unless $trailing_slash;
        $pattern .= '$';
    }

    return qr{^$pattern};
}

sub _rep_build
{
    my ($self, $switch, $token, %args) = @_;

    if (!defined $token) {
        return $switch unless __matchall($switch);
        $token = $switch;
    }

    my $rep = $args{$token} // $self->defaults->{$token} // '';
    if (!__optional($switch) && !$rep) {
        return '{?' . $token . '}';
    }

    my $check = $self->check->{$token};
    if ($check && $args{$token} !~ $check) {
        return '{!' . $token . '}';
    }

    return $rep;
}

sub build
{
    my ($self, %args) = @_;

    my $pattern = $self->pattern;
    if (ref $pattern eq 'Regexp') {
        carp "Can't build a path for regular expressions";
        return;
    }

    my $placeholder_pattern = qr{
        \{?            # may be embraced in curlies
            ( [:*?>] ) # placeholder sigil
            ( \w+ )?   # placeholder label
        \}?
    }x;

    $pattern =~ s/$placeholder_pattern/$self->_rep_build($1, $2, %args)/eg;
    if ($pattern =~ /{([!?])(\w+|[*>])}/) {
        carp $1 eq '!'
            ? "Field $2 doesn't match checks"
            : "Default value for field $2 is missing";
        return;
    }
    return $pattern;
}

sub match
{
    my ($self, $path, $method) = @_;
    return 0 if ($self->method && $self->method ne ($method // ''));
    return 0 unless my @matched = $path =~ $self->regex;
    my $has_matches = $#+;    # see perlvar @+

    # Initialize the named parameters hash and its default values
    my %named = (%{$self->defaults}, %+);

    if (@{$self->{_tokens}}) {

        # values of the named placeholders in the order they appear in the
        # regex.
        @matched = map { $named{$_} } @{$self->{_tokens}};
    }
    elsif ($has_matches) {
        @matched = map { length($_ // '') ? $_ : undef } @matched;
    }
    else {
        @matched = ();
    }

    $self->named(\%named);
    $self->param(\@matched);

    return 1;
}

sub compare
{
    my ($self, $other) = @_;

    return $other->bridge <=> $self->bridge
        || $self->order <=> $other->order
        || $self->pattern cmp $other->pattern;
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

=head2 method

Specifies an HTTP method to be matched by the route.

    my $p = Kelp::Routes::Patters->new(
        pattern => '/:id/*other',
        method  => 'PUT'
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

=head2 has_name

A boolean signifying whether this route was originally given a specific name.
It will be false if the name was taken from C<pattern>.

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

=head2 order

A numeric order of this route. Default order is C<0>, so if you want some
routes to take priority, you can use C<-1>. Lower is earlier.

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

=head2 dest

The loaded destination. An array reference with two values, a controller name
(or undef if not a controller) and the code reference to the method. It will be
automatically generated by the router based on the contents of L</to>.

=head2 psgi_middleware

Extra middleware for Kelp, for this route only. It must be a code reference,
and the middleware must wrap L<Kelp/NEXT_APP>.

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

If the pattern contains an unnamed wildcard C<*> or slurpy C<< > >>, then it
should be built like this:

    my $p = Kelp::Routes::Patters->new( pattern  => '/hello/*/>' );
    $p->build( '*' => 'kelp', '>' => 'world' ); # Returns '/hello/kelp/world'

If the pattern contains more than one unnamed items, then you should
probably give them some names.

=head2 compare

C<$compare( $other )>

Compares two routes. Used for sorting matched routes in a router.

=head1 ACKNOWLEDGEMENTS

This module was inspired by L<Routes::Tiny>.

The concept of bridges was borrowed from L<Mojolicious>

=cut

