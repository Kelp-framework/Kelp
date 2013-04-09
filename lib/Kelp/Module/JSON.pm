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

Kelp::Module::JSON - Simple JSON module for a Kelp application

=head1 SYNOPSIS

    package MyApp;
    use Kelp::Base 'Kelp';

    sub some_route {
        my $self = shift;
        return $self->json->encode( { yes => 1 } );
    }

=head1 REGISTERED METHODS

This module registers only one method into the application: C<json>.

=cut
