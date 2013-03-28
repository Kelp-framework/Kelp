package Kelp::Module::JSON;

use Kelp::Base 'Kelp::Module';
use JSON;

sub build {
    my ( $self, %args ) = @_;
    my $json = JSON->new;
    $json->allow_blessed->convert_blessed->utf8;
    $json->pretty(1) if $self->app->mode eq 'development';
    $self->register( json => $json );
}

1;
