package Kelp::Util;

# No Kelp::Base here, because Kelp::Base uses Kelp::Util;
use v5.10;
use strict;
use warnings;

use Carp;
use Data::Dumper qw();
use Encode qw();
use Class::Inspector;
use Plack::Util;
use Test::Deep::NoTest qw(eq_deeply);
use Scalar::Util qw(reftype);

# improve error locations of croak
our @CARP_NOT = (
    qw(
        Kelp
        Kelp::Base
        Kelp::Routes
        Kelp::Context
    )
);

sub _DEBUG
{
    my ($stage, @messages) = @_;
    my $env = $ENV{KELP_DEBUG};
    return if !$env;
    return if !grep { lc $env eq $_ } '1', 'all', lc $stage;

    local $Data::Dumper::Sortkeys = 1;
    my $message = join ' ', map {
        ref $_ ? Data::Dumper::Dumper($_) : $_
    } @messages;

    print "DEBUG: $message\n";
}

sub camelize
{
    my ($string, $base, $class_only) = @_;
    return $string unless $string;

    my $sigil = defined $string && $string =~ s/^(\+)// ? $1 : undef;
    $base = undef if $sigil;

    my @parts;
    if ($string !~ /#/) {

        # do not camelize if it doesn't look like a camelize string
        @parts = ($string);
    }
    else {
        @parts = split /\#/, $string;
        my $sub = pop @parts;

        push @parts, $sub
            if $class_only;

        @parts = map {
            join '', map { ucfirst lc } split /\_/
        } @parts;

        push @parts, $sub
            if !$class_only;
    }

    unshift @parts, $base if $base;
    return join('::', @parts);
}

sub extract_class
{
    my ($string) = @_;
    return undef unless $string;

    if ($string =~ /^(.+)::(\w+)$/ && $1 ne 'main') {
        return $1;
    }

    return undef;
}

sub extract_function
{
    my ($string) = @_;
    return undef unless $string;

    if ($string =~ /^(.+)::(\w+)$/) {
        return $2;
    }

    return $string;
}

sub effective_charset
{
    my $this_charset = shift;
    return Encode::find_encoding($this_charset) ? $this_charset : undef;
}

sub charset_encode
{
    my ($charset, $string) = @_;

    return $string unless $charset;
    return Encode::encode $charset, $string;
}

sub charset_decode
{
    my ($charset, $string) = @_;

    return $string unless $charset;
    return Encode::decode $charset, $string;
}

sub adapt_psgi
{
    my ($app) = @_;

    croak 'Cannot adapt_psgi, unknown destination type - must be a coderef'
        unless ref $app eq 'CODE';

    return sub {
        my $context = shift->context;
        my $path = charset_encode($context->app->request_charset, pop() // '');
        my $env = $context->req->env;

        # remember script and path
        my $orig_script = $env->{SCRIPT_NAME};
        my $orig_path = $env->{PATH_INFO};

        # adjust slashes in paths
        my $trailing_slash = $orig_path =~ m{/$} ? '/' : '';
        $path =~ s{^/?}{/};
        $path =~ s{/?$}{$trailing_slash};

        # adjust script and path
        $env->{SCRIPT_NAME} = $orig_path;
        $env->{SCRIPT_NAME} =~ s{\Q$path\E$}{};
        $env->{PATH_INFO} = $path;

        # run the callback
        my $result = $app->($env);

        # restore old script and path
        $env->{SCRIPT_NAME} = $orig_script;
        $env->{PATH_INFO} = $orig_path;

        # produce a response
        if (ref $result eq 'ARRAY') {
            my ($status, $headers, $body) = @{$result};

            my $res = $context->res;
            $res->status($status) if $status;
            $res->headers($headers) if $headers;
            $res->body($body) if $body;
            $res->rendered(1);
        }
        elsif (ref $result eq 'CODE') {
            return $result;
        }

        # this should be an error unless already rendered
        return;
    };
}

sub load_package
{
    my $package = shift;
    state $loaded = {};

    # only load package once for a given class name
    return $loaded->{$package} //= do {
        Plack::Util::load_class($package)
            unless Class::Inspector->loaded($package);
        $package;
    };
}

sub merge
{
    my ($a, $b, $allow_blessed, $sigil) = @_;
    my $ref = $allow_blessed ? sub { reftype $_[0] // '' } : sub { ref $_[0] };

    return $b
        if !$ref->($a)
        || !$ref->($b)
        || $ref->($a) ne $ref->($b);

    if ($ref->($a) eq 'ARRAY') {
        return $b unless $sigil;
        if ($sigil eq '+') {
            for my $e (@$b) {
                push @$a, $e unless grep { eq_deeply($_, $e) } @$a;
            }
        }
        else {
            $a = [
                grep {
                    my $e = $_;
                    !grep { eq_deeply($_, $e) } @$b
                } @$a
            ];
        }
        return $a;
    }
    elsif ($ref->($a) eq 'HASH') {
        for my $k (keys %$b) {

            # If the key is an array then look for a merge sigil
            my $s = $ref->($b->{$k}) eq 'ARRAY' && $k =~ s/^(\+|\-)// ? $1 : '';

            $a->{$k} =
                exists $a->{$k}
                ? merge($a->{$k}, $b->{"$s$k"}, $allow_blessed, $s)
                : $b->{$k};
        }

        return $a;
    }
    return $b;
}

1;

__END__

=pod

=head1 NAME

Kelp::Util - Kelp general utility functions

=head1 SYNOPSIS

    use Kelp::Util;

    # MyApp::A::b
    say Kelp::Util::camelize('a#b', 'MyApp');

    # Controller
    say Kelp::Util::extract_class('Controller::Action');

    # Action
    say Kelp::Util::extract_function('Controller::Action');


=head1 DESCRIPTION

These are some helpful functions not seen in L<Plack::Util>.

=head1 FUNCTIONS

No functions are exported and have to be used with full package name prefix.

=head2 camelize

This function accepts a string and a base class. Does three things:

=over

=item * transforms snake_case into CamelCase for class names (with lowercasing)

=item * replaces hashes C<#> with Perl package separators C<::>

=item * constructs the class name in similar fasion as L<Plack::Util/load_class>

=back

The returned string will have leading C<+> removed and will be prepended with
the second argument if there was no C<+>. An optional third argument can also
be passed to treat the entire string as a class name.

Will not do the camelizing if there is no C<#> sign in the string, even if
the third argument is present.

=head2 extract_class

Extracts the class name from a C<Controller::action> string. Returns undef if
no class in the string or the class is C<main>.

=head2 extract_function

Extracts the function name from a string. If there is no class name, returns
the entire string. Returns undef for empty strings.

=head2 effective_charset

Takes a charset name and returns it back if it is supported by Encode.
If there is no charset or it isn't supported, undef will be returned.

=head2 adapt_psgi

Transforms a given Plack/PSGI application (in form of a runner subroutine) to a
Kelp route handler. The route handler will take the last argument matched from
a pattern and adjust the proper environmental paths of the PSGI standard. This
will make the application mostly behave as if it was mounted directly where the
route points minus the last placeholder. For example, route C</app> will adjust
the script name to C<'/app'> and path info will always be empty, while route
C<< /app/>rest >> will have the same script name and path info set to whatever
was after C</app> in the URL (trailing slashes included).

NOTE: having more than one placeholder in the pattern is mostly wasteful, as
their matched values will not be handled in any way (other than allowing a
varying request path).

=head2 load_package

Takes a name of a package and loads it efficiently.

=head2 merge

    my $merged = Kelp::Util::merge($val1, $val2, $allow_blessed);

Merges two structures. Used by config module to merge configuration files.
Optionally, a third argument can be passed to allow merging values of blessed
references as well.

=cut

