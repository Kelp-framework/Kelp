package Kelp::Module::Template;

use Kelp::Base 'Kelp::Module';
use Kelp::Template;

attr ext => 'tt';
attr engine => sub { die "'engine' must be initialized" };

sub build
{
    my ($self, %args) = @_;

    # Build and initialize the engine attribute
    $self->engine($self->build_engine(%args));

    # Register one method - template
    $self->register(
        template => sub {
            my ($app, $template, $vars, @rest) = @_;
            $vars //= {};
            $vars->{app} //= $app;

            return $self->render($self->_rename($template), $vars, @rest);
        }
    );
}

sub build_engine
{
    my ($self, %args) = @_;
    return Kelp::Template->new(%args);
}

sub render
{
    my ($self, $template, $vars) = @_;
    return $self->engine->process($template, $vars);
}

sub _rename
{
    my ($self, $name) = @_;
    $name //= '';
    return undef unless length $name;

    my $ext = $self->ext // '';
    return $name unless length $ext;

    return $name if ref($name) || $name =~ /\./;
    return "$name.$ext";
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
uses L<Kelp::Template>, but it could be easily subclassed to use anything else.

=head1 REGISTERED METHODS

=head2 template

C<template($filename, \%vars)>

Renders a file using the currently loaded template engine. If the file doesn't
have an extension, the one specified in L</ext> will be assigned to it.

If there is no C<app> in C<%vars>, it will be automatically added.

=head1 ATTRIBUTES

=head2 ext

The default extension of the template files. This module sets this attribute to
C<tt>, so

    $self->template( 'home' );

will look for C<home.tt>. Set to undef or empty string to skip adding the
extension to filenames.

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

To process templates in utf8, add the C<encoding> to the module configuration:

    # conf/config.pl
    {
        modules      => ['Template'],
        modules_init => {
            Template => {
                encoding => 'utf8'
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

=item

Overrides the L</build_engine> method and creates an instance of the new
template engine.

    sub build_engine {
        my ( $self, %args ) = @_;
        return Text::Haml->new( %args );
    }

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

=back

=cut

