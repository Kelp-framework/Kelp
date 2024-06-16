package Kelp::Request;

use Kelp::Base 'Plack::Request';

use Carp;
use Try::Tiny;

attr -app => sub { croak "app is required" };

# The stash is used to pass values from one route to another
attr stash => sub { {} };

# The named hash contains the values of the named placeholders
attr named => sub { {} };

# The name of the matched route for this request
attr route_name => sub { undef };

# copy of json_content, used repeatedly by param
attr _param_json_content => sub {
    my $hash = $_[0]->json_content // {};
    ref $hash eq 'HASH' ? $hash : { ref $hash, $hash };
};

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
    return 0 unless my $with = $self->headers->header('X-Requested-With');
    return $with =~ m{XMLHttpRequest}i;
}

sub is_json {
    my $self = shift;
    return 0 unless $self->content_type;
    return $self->content_type =~ m{^application/json}i;
}

sub json_content {
    my $self = shift;
    return undef unless $self->is_json;

    return try {
        $self->app->json->decode( $self->content );
    }
    catch {
        undef;
    };
}

sub param {
    my $self = shift;

    if ( $self->is_json && $self->app->can('json') ) {
        my $hash = $self->_param_json_content;

        return $hash->{ $_[0] } if @_;
        if (!wantarray) {
            carp "param() called in scalar context on json request is deprecated and will return the number of keys in the future. Use json_content instead";
            return $hash;
        }
        return keys %$hash;
    }

    # safe method of calling Plack::Request::param
    return scalar $self->cgi_param($_[0]) if @_;
    return $self->cgi_param;
}

sub cgi_param {
    shift->SUPER::param(@_);
}

sub session {
    my $self    = shift;
    my $session = $self->env->{'psgix.session'}
      // croak "No Session middleware wrapped";

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

Returns a hashref, which represents the stash of the current the request

An all use, utility hash to use to pass information between routes. The stash
is a concept originally conceived by the developers of L<Catalyst>. It's a hash
that you can use to pass data from one route to another.

    # put value into stash
    $self->req->stash->{username} = app->authenticate();
    # more convenient way
    $self->stash->{username} = app->authenticate();

    # get value from stash
    return "Hello " . $self->req->stash->{username};
    # more convenient way
    return "Hello " . $self->stash('username');

=head2 named

This hash is initialized with the named placeholders of the path that the
current route is processing.

=head2 route_name

Contains a string name of the route matched for this request. Contains route pattern
if the route was not named.

=head2 param

Returns the HTTP parameters of the request. It has two modes of operation.

=over

=item

If passed with a parameter, returns the value value of a parameter with that
name from either request body or query. This always returns a scalar value.

=item

If passed without parameters, returns the list containing the names of
available parameters. This always returns a list.

=back

The behavior is changed when the content type of the request is
C<application/json> and a JSON module is loaded. In that case, it will decode
the JSON body and return values from it instead. If the root contents of the
JSON document is not an C<HASH> (after decoding), then it will be wrapped into
a hash with its reftype as a key, for example:

    { ARRAY => [...] } # when JSON contains an array as root element
    { '' => [...] }    # when JSON contains something that's not a reference

    my $array_ref = $kelp->param('ARRAY');

There also exists a special, deprecated behavior of C<param> returning the
entire contents of json when called without arguments in scalar context. This
will be later removed, so that C<param> will work exactly the same regardless
of whether the request was json. Use L</json_content> for that instead.

Since this method has so many ways to use it, you're encouraged to use
other, more specific methods from L<Plack::Request>.

=head2 cgi_param

Calls C<param> in L<Plack::Request>, which is CGI.pm compatible. It is B<not
recommended> to use this method, unless for some reason you have to maintain
CGI.pm compatibility. Misusing this method can lead to bugs and security
vulnerabilities.

=head2 json_content

Returns the json-decoded body of the request or undef if the request is not
json, there is no json decoder or an error occured.

=head2 address, remote_host, user

These are shortcuts to the REMOTE_ADDR, REMOTE_HOST and REMOTE_USER environment
variables.

    if ( $self->req->address eq '127.0.0.1' ) {
        ...
    }

Note: See L<Kelp::Cookbook/Deploying> for configuration required for these
fields when using a proxy.

=head2 session

Returns the Plack session hash or croaks if no C<Session> middleware was included.

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

Delete session value:

    delete $self->req->session->{'useless'};

=head2 is_ajax

Returns true if the request was called with C<XMLHttpRequest>.

=head2 is_json

Returns true if the request's content type was C<application/json>.

=cut

