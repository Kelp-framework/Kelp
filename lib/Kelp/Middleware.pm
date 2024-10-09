package Kelp::Middleware;

use Kelp::Base;
use Plack::Util;
use Kelp::Util;
use Carp;

attr -app => sub { croak 'app is required' };

sub wrap
{
    my ($self, $psgi) = @_;

    if (defined(my $middleware = $self->app->config('middleware'))) {
        for my $class (@$middleware) {

            # Make sure the middleware was not already loaded
            # This does not apply for testing, in which case we want
            # the middleware to wrap every single time
            next if $self->{_loaded_middleware}->{$class}++ && !$ENV{KELP_TESTING};

            my $mw = Plack::Util::load_class($class, 'Plack::Middleware');
            my $args = $self->app->config("middleware_init.$class") // {};

            Kelp::Util::_DEBUG(modules => "Wrapping app in $mw middleware with args: ", $args);

            $psgi = $mw->wrap($psgi, %$args);
        }
    }

    return $psgi;
}

1;

__END__

=pod

=head1 NAME

Kelp::Middleware - Kelp app wrapper (PSGI middleware)

=head1 SYNOPSIS

    middleware => [qw(TrailingSlashKiller Static)],
    middleware_init => {
        TrailingSlashKiller => {
            redirect => 1,
        },
        Static => {
            path => qr{^/static},
            root => '.',
        },
    }

=head1 DESCRIPTION

This is a small helper object which wraps Kelp in PSGI middleware. It is loaded
and constructed by Kelp based on the value of L<Kelp/middleware_obj> (class
name).

=head1 ATTRIBUTES

=head2 app

Main application object. Required.

=head1 METHODS

=head2 wrap

    $wrapped_psgi = $object->wrap($psgi)

Wraps the object in all middlewares according to L</app> configuration.

