package Kelp::Module::Routes;

use Carp;
use Kelp::Base 'Kelp::Module';
use Plack::Util;

our @CARP_NOT = qw(Kelp::Module Kelp);

my $DEFAULT_ROUTER = 'Kelp::Routes';

sub build
{
    my ($self, %args) = @_;

    my $router = delete($args{router}) // ('+' . $DEFAULT_ROUTER);

    my $router_class = Plack::Util::load_class($router, $DEFAULT_ROUTER);
    my $r = $router_class->new(%args);

    # Register two methods:
    # * routes - contains the routes instance
    # * add_route - a shortcut to the 'add' method
    $self->register(
        routes => $r,
        add_route => sub {
            my $app = shift;
            return $r->add(@_);
        }
    );
}

1;

__END__

=head1 NAME

Kelp::Module::Routes - Default router module for Kelp

=head1 SYNOPSIS

    # config.pl
    {
        # This module is included by default
        # modules      => ['Routes'],
        modules_init => {
            Routes => {
                base => 'MyApp'
            }
        }
    }

    # lib/MyApp.pm
    sub build {
        my $self = shift;
        mt $self->add_route('/', 'home');
    }


=head1 DESCRIPTION

This module and L<Kelp::Module::Config> are automatically loaded into each Kelp
application. It initializes the routing table for the web application.

=head1 REGISTERED METHODS

This module registers the following methods into the underlying app:

=head2 routes

An instance to L<Kelp::Routes>, or whichever router was specified in the
configuration.

=head2 add_route

A shortcut to the L<Kelp::Routes/add> method.

=head2 CONFIGURATION

The configuration for this module contains the following keys:

=head3 router

The router class to use. The default value is C<Kelp::Routes>, but any other
class can be specified. A normal string will be considered a subclass of
C<Kelp::Routes>, for example:

    router => 'Custom'

will look for C<Kelp::Routes::Custom>. To specify a fully qualified class,
prefix it with a plus sign.

    router => '+My::Special::Router'

=head3 configuration of the router

All other configuration is passed to the router. For the configuration of the
default router, see L<Kelp::Routes/ATTRIBUTES>.

