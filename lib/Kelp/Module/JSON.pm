package Kelp::Module::JSON;

use Kelp::Base 'Kelp::Module';
use JSON;

sub build {
    my ( $self, %args ) = @_;
    my $json = JSON->new;
    $json->allow_blessed->convert_blessed->utf8;
#    for ( my ( $key, $value ) = each %args ) {
#        $json->$key($value);
#    }
    $self->register( json => $json );
}

1;
