package CustomContext::Controller;

use Kelp::Base;
use Carp;

attr -context => sub { croak 'context is required' };

sub app
{
    return $_[0]->context->app;
}

sub req
{
    return $_[0]->context->req;
}

sub res
{
    return $_[0]->context->res;
}

sub before_finalize
{
    my $self = shift;
    $self->res->header('X-Final' => __PACKAGE__);
}

sub build
{
    my $self = shift;
    return unless ref $self eq __PACKAGE__;

    my $app = $self->app;

    $app->add_route(
        '/a' => {
            to => 'bridge',
            bridge => 1,
        }
    );
    $app->add_route('/a/b/c' => 'foo#test');
    $app->add_route(
        '/a/b/e' => {
            to => 'foo#nested_psgi',
            psgi => 1,
        }
    );
    $app->add_route('/b' => 'foo#test_template');
}

sub bridge
{
    return ref shift() eq __PACKAGE__;
}

1;

