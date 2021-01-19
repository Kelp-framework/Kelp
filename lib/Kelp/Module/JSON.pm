package Kelp::Module::JSON;

use Kelp::Base 'Kelp::Module';

use JSON::MaybeXS;

sub build {
    my ( $self, %args ) = @_;
    my $json = JSON::MaybeXS->new(
        map { $_ => $args{$_} } keys %args
    );
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

The module will try to use backends in this order: I<Cpanel::JSON::XS, JSON::XS, JSON::PP>.

=cut
