package Kelp::Request;

use Kelp::Base 'Plack::Request';

use Encode;
use Carp;
use Try::Tiny;

attr -app => sub { confess "app is required" };

# The stash is used to pass values from one route to another
attr stash => {};

# The named hash contains the values of the named placeholders
attr named => {};

sub new {
    my ( $class, %args ) = @_;
    my $self = $class->SUPER::new( delete $args{env} );
    $self->{$_} = $args{$_} for keys %args;
    return $self;
}

sub is_ajax {
    my $self = shift;
    return unless my $with = $self->headers->header('X-Requested-With');
    return $with =~ /XMLHttpRequest/i;
}

sub is_json {
    my $self = shift;
    return unless $self->content_type;
    return lc($self->content_type) eq 'application/json';
}

sub param {
    my $self = shift;

    if ( $self->is_json ) {
        croak "No JSON decoder" unless $self->app->can('json');
        my $hash = $self->app->json->decode( $self->content );
        croak "JSON hash expected" unless ref($hash) eq 'HASH';
        return @_ ? $hash->{$_[0]} : keys %$hash;
    }

    return $self->SUPER::param(@_);
}

no Kelp::Base;

1;


