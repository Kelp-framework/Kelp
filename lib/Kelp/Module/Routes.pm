package Kelp::Module::Routes;

use Kelp::Base 'Kelp::Module';
use Plack::Util;

my $DEFAULT_ROUTER = 'Kelp::Routes';

sub build {
    my ( $self, %args ) = @_;

    my $router = delete($args{router}) // ('+' . $DEFAULT_ROUTER);

    # A module name with a leading + indicates it's already fully
    # qualified (i.e., it does not need the Kelp::Routes:: prefix).
    my $prefix = $router =~ s/^\+// ? undef : $DEFAULT_ROUTER;

    my $router_class = Plack::Util::load_class( $router, $prefix );
    my $r = $router_class->new( %args );

    # Register two methods:
    # * routes - contains the routes instance
    # * add_route - a shortcut to the 'add' method
    $self->register(
        routes    => $r,
        add_route => sub {
            my $app = shift;
            return $r->add(@_);
        }
    );
}

1;

__END__

=pod

=head1 NAME

Kelp::Module::Routes - Default router module for Kelp

=head1 SYNOPSIS

    # config.pl
    {
        modules      => ['Routes'],    # included by default
        modules_init => {
            Routes => {
                base => 'MyApp'
            }
        }
    }

    # lib/MyApp.pm
    sub build {
        my $self = shift;
        mt $self->add_route( '/', 'home' );
    }


=head1 DESCRIPTION

This module and L<Kelp::Module::Config> are automatically loaded into each Kelp
application. It initializes the routing table for the web application.

=head1 REGISTERED METHODS

This module registers the following methods into the underlying app:

=head2 routes

An instance to L<Kelp::Routes>, or whichever router was specified in the
configuration.

    # lib/MyApp.pm
    sub build {
        my $self = shift;
        $self->routes->add( '/', 'home' );
    }

=head2 add_route

A shortcut to the L<Kelp::Routes/add> method.

=head2 CONFIGURATION

The configuration for this module containes the following keys:

=head3 router

The router class to use. The default value is C<Kelp::Routes>, but any other
class can be specified. A normal string will be considered a subclass of
C<Kelp::Routes>, for example:

    router => 'Custom'

will look for C<Kelp::Routes::Custom>. To specify a fully qualified class,
prefix it with a plus sign.

    router => '+My::Special::Router

See L<Kelp::Routes::Controller> for a router class that reblesses the
application instance.

=head3 base

Specifies the base class of each route. This saves a lot of typing when writing
the routes definitions.

    base => 'MyApp'

Now when defining a route you can only type 'myroute' to denote
'MyApp::myroute'.


=cut
