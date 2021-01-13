package Kelp::Module::JSON;

use Kelp::Base 'Kelp::Module';

BEGIN { $ENV{PERL_JSON_BACKEND} //= 'Cpanel::JSON::XS,JSON::XS,JSON::PP' }
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

The module will try to use backends in this order: I<Cpanel::JSON::XS, JSON::XS, JSON::PP>.
It can be changed by explicitly setting the I<PERL_JSON_BACKEND> environmental variable.
See L<JSON/CHOOSING BACKEND> for more details.

=cut
