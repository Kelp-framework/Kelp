package MyApp3;
use parent 'Kelp';
use strict;
use warnings;

# This route will be inherited by subclasses
sub greet {
    my ($self, $name) = @_;
    return "Bonjour, $name";
}

sub goodbye {
    my ($self, $name) = @_;
    return "Au revoir, $name";
}

1;
