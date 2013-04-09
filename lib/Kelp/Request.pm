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
        return @_ ? $hash->{$_[0]} : (wantarray ? keys %$hash : $hash);
    }

    return $self->SUPER::param(@_);
}

1;

__END__

=pod

=head1 NAME

Kelp::Request - Request class for a Kelp application

=head1 SYNOPSIS

    my $request = Kelp::Request( app => $app, env => $env );

=head1 DESCRIPTION

This module provides a convenience layer on top of L<Plack::Request>. It extends
it to add several convenience methods.

=head1 ATTRIBUTES

=head2 app

A reference to the Kelp application.

=head2 stash

An all use, utility hash to use to pass information between routes.

=head2 named

This hash is initialized with the named placeholders of the path that the
current route is processing.

=head2 param

Returns the HTTP parameters of the request. This method delegates all the work
to L<Plack::Request/param>, except when the content type of the request is
C<application/json>. In that case, it will decode the JSON body and return as
follows:

=over

=item

If no arguments are passed, then it will return the names of the HTTP parameters
when called in array contest, and a reference to the entire JSON hash when
called in scalar context.

    # JSON body = { bar => 1, foo => 2 }
    my @names = $self->param;   # @names = ('bar', 'foo')
    my $json = $self->param;    # $json = { bar => 1, foo => 2 }


=cut

=item

If a single argument is passed, then the corresponding value in the JSON
document is returned.

    my $bar = $self->param('bar');  # $bar = 1

=cut

=back

=head2 is_ajax

Returns true if the request was called with C<XMLHttpRequest>.

=head2 is_json

Returns true if the request's content type was C<application/json>.

=cut

