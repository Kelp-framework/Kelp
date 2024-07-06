package CustomContext::Context;

use Kelp::Base 'Kelp::Context';
use Kelp::Util;

attr persistent_controllers => !!1;

sub build_controller
{
    my ($self, $controller_class) = @_;

    $controller_class->new(
        context => $self,
    );
}

1;

