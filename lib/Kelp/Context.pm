package Kelp::Context;

use Kelp::Base;
use Kelp::Util;
use Carp;

attr req => undef;
attr res => undef;

attr -app => sub { croak 'app is required' };
attr -_controllers => sub { {} };
attr persistent_controllers => sub { $_[0]->app->config('persistent_controllers') };
attr current => sub { shift->app };

# loads the class, reblesses and returns - can be used to get controller on
# demand with partial or unloaded class name
sub controller
{
    my ($self, $controller) = @_;
    my $base = $self->app->routes->base;
    $controller = '+' . $base
        if !defined $controller;

    $controller = Kelp::Util::camelize($controller, $base, 1);
    Kelp::Util::load_package($controller);

    croak "Invalid controller, not subclassing $base"
        unless $controller->isa($base);

    return $self->_controllers->{$controller} //=
        $self->app->_clone($controller);
}

# reblesses, remembers and sets the current controller - used internally
sub set_controller
{
    my ($self, $controller) = @_;

    # the controller class should already be loaded by the router
    my $current = $self->_controllers->{$controller} //=
        $self->app->_clone($controller);

    $self->current($current);
    return $current;
}

# clears the object for the next route - used internally
sub clear
{
    my $self = shift;

    %{$self->_controllers} = ()
        unless $self->persistent_controllers;
    $self->current($self->app);
}

1;

# Advanced usage only. Should not be instantiated manually.
# This is a small helper object which keeps track of the context in which the
# app currently is. It also remembers all the constructed controllers until it
# is cleared - which usually is at the start of the request.

