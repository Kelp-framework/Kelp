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
