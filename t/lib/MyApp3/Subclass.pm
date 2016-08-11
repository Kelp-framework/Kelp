package MyApp3::Subclass;
use parent 'MyApp3';
use strict;
use warnings;

sub build {
    my $self = shift;
    my $r    = $self->routes;
    $r->add( "/test",        sub { "OK" } );
    $r->add( "/greet/:name", 'greet'      );
    $r->add( "/bye/:name",   'adieu'      );
}

sub adieu {
    my ($self, $name) = @_;
    return $self->goodbye($name);
}

1;
