package Kelp::Module::JSON;

use Kelp::Base 'Kelp::Module';
use JSON;

sub build {
    my ( $self, %args ) = @_;
    my $json = JSON->new;
    $json->property( $_ => $args{$_} ) for keys %args;
    $self->register( json => $json );
}

1;

__END__

=head1 NAME

Kelp::Module::JSON - Simple json module for a Kelp application

=head1 SYNOPSIS

    package MyApp;
    use Kelp::Base 'Kelp';

    sub some_route {
        my $self = shift;
        return $self->json->encode( { yes => 1 } );
    }

=head1 SEE ALSO

L<Kelp>

=head1 CREDITS

Author: Stefan Geneshky - minimal@cpan.org

=head1 LICENSE

Same as Perl itself.

=cut
