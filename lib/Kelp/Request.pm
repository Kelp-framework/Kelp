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

1;

__END__

=pod

=head1 NAME

Kelp::Request - Request class for a Kelp app

=head1 SYNOPSIS

    my $request = Kelp::Request( app => $app, env => $env );

=head1 DESCRIPTION

    This module provides a convenience layer on top of L<Plack::Request>. It
    inherits all of of its methods and adds some more.

=head1 ATTRIBUTES

=head2 app

A reference to the Kelp application.

=head2 stash

An all use, utility hash to use to pass information between routes.

=head2 named

This hash is initialized with the named placeholders of the path that the
current route is processing.


=end

