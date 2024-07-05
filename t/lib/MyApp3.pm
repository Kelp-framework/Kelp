package MyApp3;
use Kelp::Base 'Kelp';

attr context_obj => 'CustomContext::Context';

sub build
{
    my $self = shift;

    $self->routes->base('CustomContext::Controller');
    $self->routes->rebless(1);

    $self->add_route(
        '/a/b' => {
            to => sub {
                return ref shift() eq __PACKAGE__;
            },
            bridge => 1,
        }
    );
    $self->add_route(
        '/a/b/d' => {
            to => sub {
                $self->res->text;
                return ref $self;
            },
        }
    );
    $self->context->controller()->build;
}

sub before_finalize
{
    my $self = shift;
    $self->res->header('X-Final' => __PACKAGE__);
}

1;

