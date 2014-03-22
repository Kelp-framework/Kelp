package Kelp::Module::Routes;

use strict;
use warnings;
use Plack::Util ();
use Kelp::Base 'Kelp::Module';

sub build {
    my ( $self, %args ) = @_;

    my $module = $args{module} // 'Kelp::Routes';

    # Create a route object
    my $class = Plack::Util::load_class( $module );
    my $r = $class->new( %args );

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
