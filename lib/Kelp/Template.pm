package Kelp::Template;

use Kelp::Base;
use Template::Tiny;
use File::Slurp;

attr paths => sub { [] };
attr encoding => 'utf8';
attr tt => sub { Template::Tiny->new };

sub process {
    my ( $self, $template, $vars ) = @_;

    # If $template is not a ref, then it's a filename.  In that case, we
    # will look for it in all specified paths and change it to its full
    # pathname.
    if ( !ref $template ) {
        for my $p ( '.', @{ $self->paths } ) {
            if ( -e ( my $fullpath = "$p/$template" ) ) {
                $template = $fullpath;
                last;
            }
        }
    }

    if ( ref($template) ne 'SCALAR' ) {
        $template = read_file(
            $template,
            binmode    => ':' . $self->encoding,
            scalar_ref => 1
        );
    }

    my $output;
    $self->tt->process( $template, $vars, \$output );
    return $output;
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

=head1 paths

An arrayref of paths to use when looking for template files.

=head1 encoding

Specifies the text encoding of the template files. The default value is C<utf8>.

=head1 METHODS

=head2 process( $template, \%vars )

Processes a template and returns the parsed text. The template may be a file name,
a reference to a text, a GLOB or an IO object.

    say $t->process(\"Hello [% who %]", { who => 'you' });

=cut
