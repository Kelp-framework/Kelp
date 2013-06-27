package Kelp::Template;

use Kelp::Base;
use Template::Tiny;

attr paths => sub { [] };
attr encoding => 'utf8';
attr tt => sub { Template::Tiny->new };

sub process {
    my ( $self, $template, $vars ) = @_;

    my $ref = ref $template;

    # A GLOB or an IO object will be read and returned as a SCALAR template
    # No reference means a file name
    if ( $ref =~ /^IO/ || $ref eq 'GLOB' || !$ref ) {
        if ( !$ref ) {
            for my $p ( '.', @{ $self->paths } ) {
                if ( -e ( my $fullpath = "$p/$template" ) ) {
                    $template = $fullpath;
                    last;
                }
            }
        }
        $template = $self->_read_file($template);
    }
    elsif ( $ref ne 'SCALAR' ) {
        die "Template reference must be SCALAR, GLOB or an IO object";
    }

    my $output;
    $self->tt->process( $template, $vars, \$output );
    return $output;
}

# File::Slurp does not work well in OSX, so we go old school here
sub _read_file {
    my ( $self, $file ) = @_;
    my $fh = ref $file ? $file : do {
        open my $h, "<:encoding(" . $self->encoding . ")", $file or die $!;
        $h;
    };
    local $/;
    my $text = <$fh>;
    close $fh unless ref $file;
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
