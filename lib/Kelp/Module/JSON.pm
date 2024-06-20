package Kelp::Module::JSON;

use Kelp::Base 'Kelp::Module';

use JSON::MaybeXS;

sub build
{
    my ($self, %args) = @_;
    my $json = JSON::MaybeXS->new(%args);
    my $json_internal = JSON::MaybeXS->new(%args, utf8 => 0);

    $self->register(json => $json);
    $self->register(_json_internal => $json_internal);
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
        $self->res->json->set_charset('UTF-8');
        $self->res->render_binary(
            $self->json->encode({ yes => 1 })
        );
    }

=head1 REGISTERED METHODS

This module registers only one method into the application: C<json>.

The module will try to use backends in this order: I<Cpanel::JSON::XS, JSON::XS, JSON::PP>.

=head1 CAVEATS

You should probably not use C<utf8>, and just encode the value into a proper
charset by hand. You may not always want to have encoded strings anyway, for
example some interfaces may encode the values themselves.

Kelp will register a second JSON encoder / decoder with all the same options
but without C<utf8>, reserved for internal use. Modifying C<json> options at
runtime will not cause the request / response encoding to change.

=cut

