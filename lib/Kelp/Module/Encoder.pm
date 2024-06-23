package Kelp::Module::Encoder;

use Kelp::Base 'Kelp::Module';

attr 'args' => undef;
attr 'encoders' => sub { {} };

# need to be reimplemented
sub encoder_name { ... }
sub build_encoder { ... }

sub build
{
    my ($self, %args) = @_;
    $self->args(\%args);

    $self->app->encoder_modules->{$self->encoder_name} = $self;
}

sub get_encoder_config
{
    my ($self, $name) = @_;

    return {
        %{$self->args},
        %{$self->app->config(join '.', 'encoders', $self->encoder_name, $name) // {}},
    };
}

sub get_encoder
{
    my ($self, $name) = @_;
    $name //= 'default';

    return $self->encoders->{$name} //=
        $self->build_encoder($self->get_encoder_config($name));
}

1;

__END__

=head1 NAME

Kelp::Module::Encoder - Base class for encoder modules

=head1 SYNOPSIS

    # Writing a new encoder module

    package My::Encoder;
    use Kelp::Base 'Kelp::Encoder';

    use Some::Class;

    sub encoder_name { 'something' }
    sub build_encoder {
        my ($self, $args) = @_;
        return Some::Class->new(%$args);
    }

    sub build {
        my ($self, %args) = @_;
        $self->SUPER::build(%args);

        # rest of module building here if necessary
    }

    1;

    # configuring a special encoder (in app's configuration)

    encoders => {
        something => {
            modified => {
                new_argument => 1,
            },
        },
    },

    # In application's code
    # will croak if encoder was not loaded
    # default second argument is 'default' (if not passed)

    $self->get_encoder('something')->encode;
    $self->get_encoder(something => 'modified')->decode;

=head1 DESCRIPTION

This is a base class for encoders which want to be compilant with the new
L<Kelp/get_encoder> method. L<Kelp::Module::JSON> is one of such modules.

This allows to have all encoders in one easy to reach spot rather than a bunch
of unrelated methods attached to the main class. It also allows to configure a
couple of named encoders with different config in
L<Kelp::Module::Config/encoders> configuration of the app.

