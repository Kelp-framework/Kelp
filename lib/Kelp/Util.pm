package Kelp::Util;

use Kelp::Base -strict;

sub camelize {
    my ( $string, $base ) = @_;
    return $string unless $string;

    my $sigil = defined $string && $string =~ s/^(\+)// ? $1 : undef;
    $base = undef if $sigil;

    my @parts = split( /\#/, $string );
    my $sub = pop @parts;

    @parts = map {
        join '', map { ucfirst lc } split /\_/
    } @parts;
    unshift @parts, $base if $base;

    return join( '::', @parts, $sub );
}

sub extract_class {
    my ( $string ) = @_;
    return undef unless $string;

    if ($string =~ /^(.+)::(\w+)$/ && $1 ne 'main') {
        return $1;
    }

    return undef;
}

sub extract_function {
    my ( $string ) = @_;
    return undef unless $string;

    if ($string =~ /^(.+)::(\w+)$/) {
        return $2;
    }

    return $string;
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

=cut

