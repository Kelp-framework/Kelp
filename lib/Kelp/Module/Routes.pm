package Kelp::Module::Routes;

use Kelp::Base 'Kelp::Module';
use Kelp::Routes;

sub build {
    my ( $self, %args ) = @_;

    # Create a Kelp::Routes object
    my $r = Kelp::Routes->new( %args );

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
