package Kelp::Context;

use Kelp::Base;
use Carp;

attr -app => sub { croak 'app is required' };
attr -controllers => sub { {} };
attr current => sub { shift->app };

sub set_controller
{
    my ($self, $controller) = @_;

    my $current = $self->controllers->{$controller} //=
        $self->app->_clone($controller);

    $self->current($current);
    return $current;
}

sub clear
{
    my $self = shift;

    %{$self->controllers} = ();
    $self->current($self->app);
}

1;

# Advanced usage only. Should not be instantiated manually.
# This is a small helper object which keeps track of the context in which the
# app currently is. It also remembers all the constructed controllers until it
# is cleared - which usually is at the start of the request.

