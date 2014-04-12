package Kelp::Module::Routes;

use Kelp::Base 'Kelp::Module';
use Plack::Util;
use Readonly;

Readonly my $DEFAULT_ROUTER => 'Kelp::Routes';

sub build {
    my ( $self, %args ) = @_;

    my $router_class = Plack::Util::load_class(
        delete($args{router}) // $DEFAULT_ROUTER
    );

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
