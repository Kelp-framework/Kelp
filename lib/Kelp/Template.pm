package Kelp::Template;

use Kelp::Base;
use Template::Tiny;
use Path::Tiny;
use Carp;

attr paths => sub { [] };
attr encoding => 'UTF-8';
attr tt => sub { Template::Tiny->new };

sub process {
    my ( $self, $template, $vars ) = @_;

    my $ref = ref $template;

    # A GLOB or an IO object will be read and returned as a SCALAR template
    # No reference means a file name
    if ( !$ref ) {
        $template = $self->_read_file($self->find_template($template));
    }
    elsif ( $ref =~ /^IO/ || $ref eq 'GLOB' ) {
        $template = $self->_read_file($template);
    }
    elsif ( $ref ne 'SCALAR' ) {
        croak "Template reference must be SCALAR, GLOB or an IO object";
    }

    my $output;
    $self->tt->process( $template, $vars, \$output );
    return $output;
}

sub find_template {
    my ( $self, $name ) = @_;

    my $file;
    for my $p ( '.', @{ $self->paths } ) {
        $file = "$p/$name";
        return $file if -e $file;
    }

    return undef;
}

sub _read_file {
    my ( $self, $file ) = @_;

    my $text = ref $file ? <$file> : path($file)->slurp(
        { binmode => ':encoding(' . $self->encoding . ')' }
    );

    return \$text;
}

1;

__END__

=pod

=head1 NAME

Kelp::Template - A very minimal template rendering engine for Kelp

=head1 SYNOPSIS

    my $t = Kelp::Template->new;
    say $t->process('file.tt', { bar => 'foo' });

=head1 DESCRIPTION

This module provides basic template rendering using L<Template::Tiny>.

=head1 ATTRIBUTES

=head2 paths

An arrayref of paths to use when looking for template files.

=head2 encoding

Specifies the text encoding of the template files. The default value is C<UTF-8>.

=head1 METHODS

=head2 process( $template, \%vars )

Processes a template and returns the parsed text. The template may be a file name,
a reference to a text, a GLOB or an IO object.

    say $t->process(\"Hello [% who %]", { who => 'you' });

=cut

