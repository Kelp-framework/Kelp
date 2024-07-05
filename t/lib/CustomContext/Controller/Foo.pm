package CustomContext::Controller::Foo;

use Kelp::Base 'CustomContext::Controller';

sub test
{
    my ($self) = @_;

    $self->app->res->text;
    return ref $self;
}

1;

