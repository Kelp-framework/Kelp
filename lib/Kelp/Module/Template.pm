package Kelp::Module::Template;

use Kelp::Base 'Kelp::Module';
use Template;
use Carp;

attr ext => 'tt';
attr engine => sub { die "'engine' must be initialized" };

sub build {
    my ( $self, %args ) = @_;

    # Build and initialize the engine attribute
    $self->engine( $self->build_engine(%args) );

    # Register one method - template
    $self->register(
        template => sub {
            my ( $app, $template, $vars, @rest ) = @_;
            return $self->render( $self->_rename($template), $vars, @rest );
        }
    );
}

sub build_engine {
    my ( $self, %args ) = @_;
    return Template->new( \%args ) || croak $Template::ERROR, "\n";
}

sub render {
    my ( $self, $template, $vars, @rest ) = @_;
    my $output;
    $self->engine->process( $template, $vars, \$output, @rest )
      || croak $self->engine->error(), "\n";
    return $output;
}

sub _rename {
    my ( $self, $name ) = @_;
    return unless $name;
    return !ref($name) && $name !~ /\.(.+)$/
      ? $name . '.' . $self->ext
      : $name;
}

1;

__END__

=pod

=head1 NAME

Kelp::Module::Template - Template processing for Kelp applications

=head1 SYNOPSIS

First ...

    # conf/config.pl
    {
        modules => ['Template'],
        modules_init => {
            Template => { ... }
        }
    };

Then ...

    # lib/MyApp.pm
    sub some_route {
        my $self = shift;
        $self->template('some_template', { bar => 'foo' });
    }

=head1 DESCRIPTION

This module provides an interface for using templates in a Kelp web application. It
uses L<Template> by default, but it could be easily subclassed to use anything
else.

=head1 REGISTERED METHODS

=head2 template

C<template($filename, \%vars)>

Renders a file using the currently loaded template engine. If the file doesn't
have an extension, the one specified in L</ext> will be assigned to it.

=head1 ATTRIBUTES

=head2 ext

The default extension of the template files. This module sets this attribute to
C<tt>, so

    $self->template( 'home' );

will look for C<home.tt>.

=head2 engine

This attribute will be initialized by the C<build_engine> method of this module,
and it is available to all code that needs access to the template engine
instance. See L</SUBCLASSING> for an example.

=head1 METHODS

=head2 build_engine

C<build_engine(%args)>

This method is responsible for creating, initializing and returning an instance
of the template engine used, for example L<Template>. Override it to use a
different template engine, for example L<Text::Haml>.

=head2 render

C<render($template, \%vars, @rest)>

This method should return a rendered text. Override it if you're subclassing and
using a different template engine.

=head1 PERKS

=head2 UTF8

L<Template> is sometimes unable to detect the correct encoding, so to ensure
proper rendering, you may want to add C<ENCODING> to its configuration:

    # conf/config.pl
    {
        modules      => ['Template'],
        modules_init => {
            Template => {
                ENCODING => 'utf8'
            }
        }
    };

=head1 SUBCLASSING

To use a different template engine, you can subclass this module. You will need
to make sure your new class does the following (for the sake of the example we
will show you how to create a L<Text::Haml> rendering module):

=over

=item

Overrides the L</ext> attribute and provides the file extension of the new
template files.

    attr ext => 'haml';

=cut

=item

Overrides the L</build_engine> method and creates an instance of the new
template engine.

    sub build_engine {
        my ( $self, %args ) = @_;
        return Text::Haml->new;
    }

=cut

=item

Overrides the L</render> method and renders using C<$self-E<gt>engine>.

    sub render {
        my ( $self, $template, $vars, @rest ) = @_;

        # Get the template engine instance
        my $haml = $self->engine;

        # If the $template is a reference, then render string,
        # otherwise it's a file name.
        return ref($template) eq 'SCALAR'
          ? $haml->render( $$template, %$vars )
          : $haml->render_file( $template, %$vars );
    }

=cut

=back


=cut
