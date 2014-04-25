package MyApp2;
use Kelp::Base 'Kelp';

sub build {
    my $self = shift;
    my $r    = $self->routes;
    $r->add( "/blessed", "blessed" );
    $r->add( "/blessed_bar", "Bar::blessed" );
    $r->add( "/blessed_bar2", "bar#blessed" );
    $r->add( "/hello", "bar#hello" );
}

1;
