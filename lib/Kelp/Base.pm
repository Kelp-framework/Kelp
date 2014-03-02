package Kelp::Base;

use strict ();
use warnings ();
use feature ();
use Carp;

sub import {
    my $class = shift;
    my $caller = caller;

    # Do not import into inherited classes
    return if $class ne __PACKAGE__;

    my $base = shift || $class;

    if ( $base ne '-strict' ) {
        no strict 'refs';
        no warnings 'redefine';

        my $file = $base;
        $file =~ s/::|'/\//g;
        require "$file.pm" unless $base->can('new'); # thanks sri

        push @{"${caller}::ISA"}, $base;
        *{"${caller}::attr"} = sub { attr( $caller, @_ ) };
    }

    strict->import;
    warnings->import;
    feature->import(':5.10');
}

sub new {
    bless { @_[ 1 .. $#_ ] }, $_[0];
}

sub attr {
    my ( $class, $name, $default ) = @_;

    if ( ref $default && ref $default ne 'CODE' ) {
        croak "Default value for '$name' can not be a reference.";
    }

    no strict 'refs';
    no warnings 'redefine';

    # Readonly attributes are marked with '-'
    my $readonly = $name =~ s/^\-//;

    *{"${class}::$name"} = sub {
        if ( @_ > 1 && !$readonly ) {
            $_[0]->{$name} = $_[1];
        }
        return $_[0]->{$name} if exists $_[0]->{$name};
        return $_[0]->{$name} =
          ref $default eq 'CODE'
          ? $default->( $_[0] )
          : $default;
    };
}

1;

__END__

=pod

=head1 NAME

Kelp::Base - Simple lazy attributes

=head1 SYNOPSIS

    use Kelp::Base;

    attr source => 'dbi:mysql:users';
    attr user   => 'test';
    attr pass   => 'secret';
    attr opts   => { PrintError => 1, RaiseError => 1 };

    attr dbh => sub {
        my $self = shift;
        DBI->connect( $self->sourse, $self->user, $self->pass, $self->opts );
    };

    # Later ...
    sub do_stuff {
        my $self = shift;
        $self->dbh->do('DELETE FROM accounts');
    }

or

    use Kelp::Base 'Module::Name';    # Extend Module::Name

or

    use Kelp::Base -strict;    # Only use strict, warnings and v5.10
                                  # No magic


=head1 DESCRIPTION

This module provides simple lazy attributes.

=head1 WHY?

Some users will naturally want to ask F<"Why not use Moose/Mouse/Moo/Mo?">. The
answer is that the Kelp web framework needs lazy attributes, but the
author wanted to keep the code light and object manager agnostic.
This allows the users of the framework to choose an object manager to
their liking.
There is nothing more annoying than a module that forces you to use L<Moose> when you
are perfectly fine with L<Moo> or L<Mo>, for example.

=head1 USAGE

    use Kelp::Base;

The above will automatically include C<strict>, C<warnings> and C<v5.10>. It will
also inject a new sub in the current class called C<attr>.

    attr name1 => 1;                      # Fixed value
    attr name2 => sub { [ 1, 2, 3 ] };    # Array
    attr name3 => sub {
        $_[0]->other;
      }

    ...

    say $self->name1;               # 1
    $self->name2( [ 6, 7, 8 ] );    # Set new value

All those attributes will be available for reading and writing in each instance
of the current class. If you want to create a read-only attribute, prefix its
name with a dash.

    attr -readonly => "something";

    # Later
    say $self->readonly;           # something
    $self->readonly("nothing");    # no change

=head1 SEE ALSO

L<Kelp>, L<Moose>, L<Moo>, L<Mo>, L<Any::Moose>

=cut
