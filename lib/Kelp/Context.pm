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

sub build_controller
{
    my ($self, $controller_class) = @_;
    return $self->app->_clone($controller_class);
}

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
        $self->build_controller($controller);
}

# reblesses, remembers and sets the current controller - used internally
sub set_controller
{
    my ($self, $controller) = @_;
    return $self->current($self->app)
        unless $controller;

    # the controller class should already be loaded by the router
    my $current = $self->_controllers->{$controller} //=
        $self->build_controller($controller);

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

# run method in current context. If current context does not provide this
# method, run it in app instead.
sub run_method
{
    my $self = shift;
    my $method = shift;
    my $c = $self->current;

    if ($c->can($method)) {
        $c->$method(@_);
    }
    else {
        $self->app->$method(@_);
    }
}

1;

__END__

=pod

=head1 NAME

Kelp::Context - Tracks Kelp application's current execution context

=head1 SYNOPSIS

    # get current controller
    $app->context->current;

    # get the application
    $app->context->app;

    # get the named controller
    $app->context->controller('Controller');

=head1 DESCRIPTION

This is a small helper object which keeps track of the context in which the
app currently is. It also remembers all the constructed controllers until it
is cleared - which usually is at the start of the request.

Advanced usage only.

It can be subclassed to change how controllers are built and handled. This
would usually involve overriding the C<build_controller> method.

=head1 ATTRIBUTES

=head2 app

Main application object. This will always be the main app, not a controller.

=head2 current

Current controller object. This will be automatically set to a proper
controller by the router.

=head2 req

=head2 res

Current request and response objects, also accessible from C<< $app->req >> and
C<< $app->res >>.

=head2 persistent_controllers

A configuration field which defines whether L</clear> destroys constructed
controllers. By default it is taken from app's configuration field of the same
name.

=head1 METHODS

=head2 build_controller

Defines how a controller is built. Can be overridden to introduce a custom
controller object instead of reblessed application.

=head2 controller

Returns a controller of a given name. The name will be mangled according to the
base route class of the application. Contains extra checks to ensure the input
is valid and loads the controller class if it wasn't loaded yet.

If the controller name is C<undef>, the base controller is returned.

=head2 set_controller

Similar to L</controller>, but does not have any special checks for correctness
and only accepts a full class name. It also modifies the L</current> to the
controller after constructing it. Passing a false value will result in
reverting the current context back to the app object.

It's optimized for speed and only used internally, so it's not recommended to
use it unless you extend Kelp router itself.

=head2 clear

Clears context in anticipation of the next request. Called automatically at the
start of every request.

=head2 run_method

    $self->context->run_method($name => @args);

This method runs method C<$name> in current context. If the current context
does not provide that method, it will be run in application context instead. It
should only be used for methods which are known to be available in application
instance.

