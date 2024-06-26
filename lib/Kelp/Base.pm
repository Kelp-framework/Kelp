package Kelp::Base;

use strict;
use warnings;
use feature ();
use Carp;

require namespace::autoclean;
require Kelp::Util;

sub import
{
    my $class = shift;
    my $caller = caller;

    # Do not import into inherited classes
    return if $class ne __PACKAGE__;

    my $base = shift || $class;

    if ($base ne '-strict') {
        no strict 'refs';
        no warnings 'redefine';

        if ($base ne '-attr') {
            Kelp::Util::load_package($base);
            push @{"${caller}::ISA"}, $base;
        }

        *{"${caller}::attr"} = sub { attr($caller, @_) };

        namespace::autoclean->import(
            -cleanee => $caller
        );
    }

    strict->import;
    warnings->import;
    feature->import(':5.10');
}

sub new
{
    my $self = shift;
    return bless {@_}, $self;
}

sub attr
{
    my ($class, $name, $default) = @_;

    if (ref $default && ref $default ne 'CODE') {
        croak "Default value for '$name' can not be a reference.";
    }

    # Readonly attributes are marked with '-'
    my $readonly = $name =~ s/^\-//;

    # Remember if default is a function
    my $default_sub = ref $default eq 'CODE';

    {
        no strict 'refs';
        no warnings 'redefine';

        *{"${class}::$name"} = sub {
            return $_[0]->{$name} = $_[1] if @_ > 1 && !$readonly;
            return $_[0]->{$name} if exists $_[0]->{$name};
            return $_[0]->{$name} = $default_sub ? $default->($_[0]) : $default;
        };
    }
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
    attr opts   =>  sub { { PrintError => 1, RaiseError => 1 } };

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
answer is that the Kelp web framework needs lazy attributes, but the author
wanted to keep the code light and object manager agnostic. This allows the
users of the framework to choose an object manager to their liking. As a nice
addition, our getters and constructors are quite a bit faster than any non-XS
variant of L<Moose>, which makes the core code very fast.

There is nothing more annoying than a module that forces you to use L<Moose>
when you are perfectly fine with L<Moo> or L<Mo>, for example. Since this
module is so minimal, you should probably switch to a full-blown OO system of
your choice when writing your application. Kelp::Base should be compatible with
it as long as it uses blessed hashes under the hood.

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

Kelp::Base can also be imported without turning an object into a class:

    # imports strict, warnings and :5.10
    use Kelp::Base -strict;

    # imports all of the above plus attr
    use Kelp::Base -attr;

The former is useful for less boilerplate in scripts on older perls. The latter
is useful when using C<attr> with L<Role::Tiny>.

=head1 SEE ALSO

L<Kelp>, L<Moose>, L<Moo>, L<Mo>, L<Any::Moose>

=cut

