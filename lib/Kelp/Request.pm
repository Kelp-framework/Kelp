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

# The name of the matched route for this request
attr route_name => sub { undef };

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
    my $safe_param = $self->app->config('safe_param') // 0;
    my $warn_message =
        'Using "param" with argument in list context is deprecated ' .
        'in Kelp version 1.04. See documentation of for details'
    ;

    if ( $self->is_json && $self->app->can('json') ) {
        my $hash = try {
            $self->app->json->decode( $self->content );
        }
        catch {
            {};
        };
        $hash = { ref($hash), $hash } unless ref($hash) eq 'HASH';

        return $hash->{ $_[0] } if @_;
        return $hash if !wantarray;
        return keys %$hash;
    }

    # unsafe method - Plack::Request::param
    if (@_ && wantarray && !$safe_param) {
        carp $warn_message;
        return $self->SUPER::param(@_);
    }

    # safe method without calling PLack::Request::param
    return $self->parameters->get($_[0]) if @_;
    return keys %{ $self->parameters };
}

sub cgi_param {
    shift->SUPER::param(@_);
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

I<B<Change of behavior> in version 1.04, see below for details>

Returns the HTTP parameters of the request. This method delegates all the work
to L<Plack::Request/param>, except when the content type of the request is
C<application/json> and a JSON module is loaded. In that case, it will decode
the JSON body and return as follows:

=over

=item

If no arguments are passed, then it will return the names of the HTTP parameters
when called in array contest, and a reference to the entire JSON hash when
called in scalar context.

    # JSON body = { bar => 1, foo => 2 }
    my @names = $self->param;   # @names = ('bar', 'foo')
    my $json = $self->param;    # $json = { bar => 1, foo => 2 }


=item

If a single argument is passed, then the corresponding value in the JSON
document is returned.

    my $bar = $self->param('bar');  # $bar = 1

=item

If the root contents of the JSON document is not an C<HASH> (after decoding), then it will be wrapped into a hash with its reftype as a key, for example:

    { ARRAY => [...] } # when JSON contains an array as root element
    { '' => [...] }    # when JSON contains something that's not a reference

    my $array = $kelp->param('ARRAY');

=back

Since version I<1.04>, a new application configuration field C<safe_param> is
introduced that B<changes the behavior> of this method:

=over

=item

Without C<safe_param>, method will produce a warning if used in list context
while passing the first argument, but will continue to work the same. This is
done to combat a very nasty and easy to make bug:

    $kelp->some_function(
        param1 => $value,
        param2 => $kelp->param('key'), # BUG, list context
    );

Since HTTP requests can accept multiple values for the same key, someone could
inject additional parameters to the function with the simple query, due to
array flattening:

    ?key=something&key=additional_hash_key&key=additional_hash_value

=item

With C<safe_param>, a call to C<param> with an argument (a key to fetch from
the parameters) will no longer return a list but always a scalar value
regardless of context, even if there are more than one entries of that name
(will then return the last one). This makes usages like the one above perfectly
safe.

    my @array = $kelp->param('name'); # changed, will never return more than one scalar

=item

Since this method has so many ways to use it, you're still B<encouraged> to use
other, more specific methods from L<Plack::Request>.

=back

You are B<strongly advised> to introduce C<safe_param> into your configuration as
quickly as possible. Currently, a value of C<0> is the default, meaning that
param will work the same as it did, but produce warnings. In no less than half
a year from version 1.04 the old behavior of C<param> will be removed
altogether, and C<safe_param> configuration will no longer cause any change in
behavior, allowing for its safe removal. Use L</cgi_param> if you'd like to
retain the old behavior regardless of security risks.

=head2 cgi_param

Calls C<param> in L<Plack::Request>, which is CGI.pm compatible. It is B<not
recommended> to use this method, unless for some reason you have to maintain
CGI.pm compatibility. Misusing this method can lead to bugs and security
vulnerabilities.

=head2 address, remote_host, user

These are shortcuts to the REMOTE_ADDR, REMOTE_HOST and REMOTE_USER environment
variables.

    if ( $self->req->address eq '127.0.0.1' ) {
        ...
    }

Note: See L<Kelp::Cookbook/Deploying> for configuration required for these
fields when using a proxy.

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

=item Delete session value

    delete $self->req->session->{'useless'};

=item Remove all session values

    $self->req->session( {} );

=back

=head2 is_ajax

Returns true if the request was called with C<XMLHttpRequest>.

=head2 is_json

Returns true if the request's content type was C<application/json>.

=cut

