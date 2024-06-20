package Kelp::Module::JSON;

use Kelp::Base 'Kelp::Module::Encoder';

use JSON::MaybeXS;

sub encoder_name { 'json' }

sub build_encoder
{
    my ($self, $args) = @_;
    return JSON::MaybeXS->new(%$args);
}

sub build
{
    my ($self, %args) = @_;
    $self->SUPER::build(%args);

    $self->register(json => $self->get_encoder);
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

        # manually render a json configured to UTF-8
        $self->res->set_charset('UTF-8');
        $self->res->render_binary(
            $self->json->encode({ yes => 1 })
        );
    }

=head1 DESCRIPTION

Standard JSON encoder/decoder. Chooses the best backend through L<JSON::MaybeXS>.

=head1 REGISTERED METHODS

This module registers only one method into the application: C<json>. It also
registers itself for later use by L<Kelp/get_encoder> under the name C<json>.

The module will try to use backends in this order: I<Cpanel::JSON::XS, JSON::XS, JSON::PP>.

=head1 CAVEATS

You should probably not use C<utf8>, and just encode the value into a proper
charset by hand. You may not always want to have encoded strings anyway, for
example some interfaces may encode the values themselves.

Kelp will use an internal copy of JSON encoder / decoder with all the same options
but without C<utf8>, reserved for internal use. Modifying C<json> options at
runtime will not cause the request / response encoding to change.

=cut

