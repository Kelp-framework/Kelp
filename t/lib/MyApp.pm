package MyApp;
use Kelp::Base 'Kelp';
use MyApp::Response;
use UtilPackage;

sub before_dispatch
{
    my $self = shift;
    $self->res->header('X-Before-Dispatch', 'MyApp');
}

sub before_finalize
{
    my $self = shift;
    $self->res->header('X-Test', 'MyApp');
}

sub build_response
{
    my $self = shift;
    MyApp::Response->new(app => $self);
}

sub build
{
    my $self = shift;
    my $r = $self->routes;
    $r->add("/test", sub { "OK" });
    $r->add("/greet/:name", "routes#greet");
    $r->add("/bye/:name", "Routes2::goodbye");

    # Controller routes
    $r->add("/blessed", "blessed");
}

sub blessed
{
    my ($self) = @_;

    $self->template('home');
}

sub check_util_fun { path; }

1;

