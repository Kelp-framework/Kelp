# NAME

Kelp::Base - Simple lazy attributes

# SYNOPSIS

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



# DESCRIPTION

This module provides simple lazy attributes.

# WHY?

Some users will naturally want to ask `"Why not use Moose/Mouse/Moo/Mo?"`. The
answer is that the Kelp web framework needs lazy attributes, but the
author wanted to keep the code light and object manager agnostic.
This allows the users of the framework to choose an object manager to
their liking.
There is nothing more annoying than a module that forces you to use [Moose](http://search.cpan.org/perldoc?Moose) when you
are perfectly fine with [Moo](http://search.cpan.org/perldoc?Moo) or [Mo](http://search.cpan.org/perldoc?Mo), for example.

# USAGE

    use Kelp::Base;

The above will automaticaly include `strict`, `warnings` and `v5.10`. It will
also inject a new sub in the current class called `attr`.

    attr name1 => 1;         # Fixed value
    attr name2 => [1,2,3];   # Array
    attr name3 => sub {
        $_[0]->other
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

# SEE ALSO

[Kelp](http://search.cpan.org/perldoc?Kelp), [Moose](http://search.cpan.org/perldoc?Moose), [Moo](http://search.cpan.org/perldoc?Moo), [Mo](http://search.cpan.org/perldoc?Mo), [Any::Moose](http://search.cpan.org/perldoc?Any::Moose)

# CREDITS

Author: minimalist - minimal@cpan.org

# LICENSE

Same as Perl itself.
