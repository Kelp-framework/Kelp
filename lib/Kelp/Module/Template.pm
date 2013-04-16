package Kelp::Module::Template;

use Kelp::Base 'Kelp::Module';
use Template;
use Carp;

attr ext => 'tt';

sub build {
    my ( $self, %args ) = @_;
    my $tt = Template->new( \%args ) || croak $Template::ERROR, "\n";

    # Register one method - template
    $self->register(
        template => sub {
            my ( $app, $template, $vars, @rest ) = @_;
            if ( !ref($template) && $template !~ /\.(.+)$/ ) {
                $template .= '.' . $self->ext;
            }
            my $output;
            $tt->process( $template, $vars, \$output, binmode => ':utf8' )
              || croak $tt->error(), "\n";
            return $output;
        }
    );
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

This module provides interface for using templates in a Kelp web application. It
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

=head1 SUBCLASSING

To use a different template engine, you can subclass this module. You only need
to override C<ext> to set the new file extension. Then register the C<template>
method with the following arguments: C<template( $filename, \%vars )>.

=cut
