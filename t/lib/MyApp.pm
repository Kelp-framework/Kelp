package MyApp;
use Kelp::Base 'Kelp';
use MyApp::Response;

sub before_finalize {
    my $self = shift;
    $self->res->header( 'X-Test', 'MyApp' );
}

sub response {
    my $self = shift;
    MyApp::Response->new( app => $self );
}

sub build {
    my $self = shift;
    my $r    = $self->routes;
    $r->add( "/test", sub { "OK" } );
    $r->add( "/greet/:name", "routes#greet");
    $r->add( "/bye/:name", "Routes2::goodbye");
}

1;
