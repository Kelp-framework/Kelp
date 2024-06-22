package Kelp::Util;

use Kelp::Base -strict;
use Carp;
use Scalar::Util qw(blessed);
use Encode qw();

sub camelize
{
    my ($string, $base) = @_;
    return $string unless $string;

    my $sigil = defined $string && $string =~ s/^(\+)// ? $1 : undef;
    $base = undef if $sigil;

    my @parts = split(/\#/, $string);
    my $sub = pop @parts;

    @parts = map {
        join '', map { ucfirst lc } split /\_/
    } @parts;
    unshift @parts, $base if $base;

    return join('::', @parts, $sub);
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
    my (@objects) = @_;

    my $charset;
    foreach my $object (@objects) {
        $charset = Encode::find_encoding(ref $object ? $object->charset : $object);
        last if $charset;
    }

    return $charset;
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
        my $kelp = shift;
        my $path = charset_encode($kelp->request_charset, pop() // '');
        my $env = $kelp->req->env;

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

            my $res = $kelp->res;
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
the second argument if there was no C<+>.

=head2 extract_class

Extracts the class name from a C<Controller::action> string. Returns undef if
no class in the string or the class is C<main>.

=head2 extract_function

Extracts the function name from a string. If there is no class name, returns
the entire string. Returns undef for empty strings.

=head2 effective_charset

Takes a list of objects to call C<charset> on and returns the first one to have
a charset supported by Encode. If there is no charset in any of the objects or
they aren't supported, undef will be returned. Can also be passed plain strings
with the charset names (instead of objects implementing C<charset> method).

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

=cut

