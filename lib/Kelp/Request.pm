package Kelp::Request;

use Kelp::Base 'Plack::Request';

use Encode;
use Carp;
use Try::Tiny;

attr -app => sub { croak "app is required" };

# The stash is used to pass values from one route to another
attr stash => sub { {} };

# The named hash contains the values of the named placeholders
attr named => sub { {} };

# If you're running the web app as a proxy, use Plack::Middleware::ReverseProxy
sub address     { $_[0]->env->{REMOTE_ADDR} }
sub remote_host { $_[0]->env->{REMOTE_HOST} }
sub user        { $_[0]->env->{REMOTE_USER} }

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
    return lc($self->content_type) =~ qr[^application/json]i;
}

sub param {
    my $self = shift;

    if ( $self->is_json ) {
        die "No JSON decoder" unless $self->app->can('json');
        my $hash = try {
            $self->app->json->decode( $self->content );
        }
        catch {
            {};
        };
        $hash = { ref($hash), $hash } unless ref($hash) eq 'HASH';
        return @_ ? $hash->{ $_[0] } : ( wantarray ? keys %$hash : $hash );
    }

    return $self->SUPER::param(@_);
}

sub session {
    my $self    = shift;
    my $session = $self->env->{'psgix.session'}
      // die "No Session middleware wrapped";

    return $session if !@_;

    if ( @_ == 1 ) {
        my $value = shift;
        return $session->{$value} unless ref $value;
        return $self->env->{'psgix.session'} = $value;
    }

    my %hash = @_;
    $session->{$_} = $hash{$_} for keys %hash;
    return $session;
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

=head2 address, remote_host, user

These are shortcuts to the REMOTE_ADDR, REMOTE_HOST and REMOTE_USER environment
variables.

    if ( $self->req->address eq '127.0.0.1' ) {
        ...
    }

Note. If you're running the web app behind nginx (or another web server), you need
to use L<Plack::Middleware::ReverseProxy>.

    # app.psgi

    builder {
        enable_if { ! $_[0]->{REMOTE_ADDR} || $_[0]->{REMOTE_ADDR} =~ /127\.0\.0\.1/ }
        "Plack::Middleware::ReverseProxy";
        $app->run;
    };

(REMOTE_ADDR is not set at all when using the proxy via filesocket).

=head2 session

Returns the Plack session hash or dies if no C<Session> middleware was included.

    sub get_session_value {
        my $self = shift;
        $self->session->{user} = 45;
    }

If called with a single argument, returns that value from the session hash:

    sub set_session_value {
        my $self = shift;
        my $user = $self->req->session('user');
        # Same as $self->req->session->{'user'};
    }

Set values in the session using key-value pairs:

    sub set_session_hash {
        my $self = shift;
        $self->req->session(
            name  => 'Jill Andrews',
            age   => 24,
            email => 'jill@perlkelp.com'
        );
    }

Set values using a Hashref:

    sub set_session_hashref {
        my $self = shift;
        $self->req->session( { bar => 'foo' } );
    }

Clear the session:

    sub clear_session {
        my $self = shift;
        $self->req->session( {} );
    }

=head3 Common tasks with sessions

=over

=item Initialize file sessions

In your config file:

    middleware => ['Session'],
    middleware_init => {
        Session => {
            store => 'File'
        }
    }

=cut

=item Delete session values

    delete $self->req->session->{'useless'};

=cut

=item Remove all session values

    $self->req->session = {};

=cut

=back

=head2 is_ajax

Returns true if the request was called with C<XMLHttpRequest>.

=head2 is_json

Returns true if the request's content type was C<application/json>.

=cut

