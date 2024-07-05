package CustomContext::Controller;

use Kelp::Base;
use Carp;

attr -app => sub { croak 'app is required' };

sub before_dispatch
{
    my $self = shift;
    $self->app->before_dispatch(@_);
}

sub before_finalize
{
    my $self = shift;
    $self->app->res->header('X-Final' => __PACKAGE__);
}

sub build
{
    my $self = shift;
    my $app = $self->app;

    $app->add_route(
        '/a' => {
            to => 'bridge',
            bridge => 1,
        }
    );
    $app->add_route('/a/b/c' => 'foo#test');
}

sub bridge
{
    return ref shift() eq __PACKAGE__;
}

1;

