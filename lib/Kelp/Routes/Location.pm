package Kelp::Routes::Location;

use Kelp::Base;
use Carp;

attr 'router' => sub { croak 'router is required' };
attr 'parent' => sub { croak 'parent is required' };

sub add {
    my ( $self, $pattern, $descr, $parent_data ) = @_;
    my $parent = $self->parent;

    croak "Cannot chain 'add' calls because the parent route was not parsed correctly"
        unless $parent;

    # discard $parent_data from args
    $parent_data = {
        ($parent->has_name ? (name => $parent->name) : ()),
        pattern => $parent->pattern,
    };

    # parent is a bridge now (even if the add call fails)
    $parent->bridge(1);
    return $self->router->add( $pattern, $descr, $parent_data );
}

1;

# internal only
# It's not a router reimplementation! It's just a facade for the add method of
# the router. Developers will interact with it without even knowing.

