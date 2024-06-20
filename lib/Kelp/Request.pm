package Kelp::Request;

use Kelp::Base 'Plack::Request';

use Carp;
use Try::Tiny;
use Encode qw(decode);
use Hash::MultiValue;

attr -app => sub { croak "app is required" };

# The stash is used to pass values from one route to another
attr stash => sub { {} };

# The named hash contains the values of the named placeholders
attr named => sub { {} };

# The name of the matched route for this request
attr route_name => sub { undef };

attr query_parameters => sub {
    my $self = shift;
    my $raw = $self->_charset_decode_array($self->_query_parameters);
    return Hash::MultiValue->new(@{$raw});
};

attr body_parameters => sub {
    my $self = shift;
    my $raw = $self->_charset_decode_array($self->_body_parameters);
    return Hash::MultiValue->new(@{$raw});
};

attr parameters => sub {
    my $self = shift;

    my $raw_query = $self->_charset_decode_array($self->_query_parameters);
    my $raw_body = $self->_charset_decode_array($self->_body_parameters);
    return Hash::MultiValue->new(@{$raw_query}, @{$raw_body});
};

# Raw methods - methods in Plack::Request (without decoding)
# in Kelp::Request, they are replaced with decoding versions

sub raw_path
{
    my $self = shift;
    return $self->SUPER::path(@_);
}

sub raw_body
{
    my $self = shift;
    return $self->SUPER::content(@_);
}

sub raw_body_parameters
{
    my $self = shift;
    return $self->SUPER::body_parameters(@_);
}

sub raw_query_parameters
{
    my $self = shift;
    return $self->SUPER::query_parameters(@_);
}

sub raw_parameters
{
    my $self = shift;
    return $self->SUPER::parameters(@_);
}

# If you're running the web app as a proxy, use Plack::Middleware::ReverseProxy
sub address { $_[0]->env->{REMOTE_ADDR} }
sub remote_host { $_[0]->env->{REMOTE_HOST} }
sub user { $_[0]->env->{REMOTE_USER} }

# Interface

sub new
{
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(delete $args{env});
    $self->{$_} = $args{$_} for keys %args;
    return $self;
}

sub is_ajax
{
    my $self = shift;
    return 0 unless my $with = $self->headers->header('X-Requested-With');
    return $with =~ m{XMLHttpRequest}i;
}

sub is_json
{
    my $self = shift;
    return 0 unless $self->content_type;
    return $self->content_type =~ m{^application/json}i;
}

sub charset
{
    my $self = shift;

    # charset must be supported by Encode
    state $supported = {map { lc $_ => $_ } Encode->encodings(':all')};

    return undef unless $self->content_type;
    return undef unless $self->content_type =~ m{;\s*charset=([^;\$]+)}i;
    return $supported->{lc $1};
}

sub charset_encode
{
    my ($self, $string) = @_;

    # Worst case scenario is a server error with code 500
    return encode $self->charset, $string
        if $self->charset;
    return $self->app->charset_encode($string);
}

sub charset_decode
{
    my ($self, $string) = @_;

    # Worst case scenario is a server error with code 500
    return decode $self->charset, $string
        if $self->charset;
    return $self->app->charset_decode($string);
}

sub _charset_decode_array
{
    my ($self, $arr) = @_;
    return [map { $self->charset_decode($_) } @$arr];
}

sub path
{
    my $self = shift;
    return $self->charset_decode($self->SUPER::path(@_));
}

sub content
{
    my $self = shift;
    return $self->charset_decode($self->SUPER::content(@_));
}

sub json_content
{
    my $self = shift;
    return undef unless $self->is_json;

    return try {
        $self->app->get_encoder(json => 'internal')->decode($self->content);
    }
    catch {
        undef;
    };
}

sub param
{
    my $self = shift;

    if ($self->is_json && $self->app->can('json')) {
        return $self->json_param(@_);
    }

    # safe method without calling Plack::Request::param
    return $self->parameters->get($_[0]) if @_;
    return keys %{$self->parameters};
}

sub cgi_param
{
    shift->SUPER::param(@_);
}

sub query_param
{
    my $self = shift;

    return $self->query_parameters->get($_[0]) if @_;
    return keys %{$self->query_parameters};
}

sub body_param
{
    my $self = shift;

    return $self->body_parameters->get($_[0]) if @_;
    return keys %{$self->body_parameters};
}

sub json_param
{
    my $self = shift;

    my $hash = $self->{_param_json_content} //= do {
        my $hash = $self->json_content // {};
        ref $hash eq 'HASH' ? $hash : {ref $hash, $hash};
    };

    return $hash->{$_[0]} if @_;
    if (!wantarray) {
        carp
            "param() called in scalar context on json request is deprecated and will return the number of keys in the future. Use json_content instead";
        return $hash;
    }
    return keys %$hash;
}

sub session
{
    my $self = shift;
    my $session = $self->env->{'psgix.session'}
        // croak "No Session middleware wrapped";

    return $session if !@_;

    if (@_ == 1) {
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
it to add several convenience methods and support for application encoding.

=head1 ENCODING

Starting with version 2.01, Kelp::Request simplifies input handling and
improves correctness by automatically decoding path, query parameters and body
parameters.

Headers (so cookies as well) are unaffected, as they aren't consistently
supported outside of ASCII range. JSON now decodes request data into the proper
charset instead of flat utf8 if so configured. Sessions are configured
separately in middlewares, so they must themselves do the proper decoding.

Following methods will return values decoded with charset either from
C<Content-Type> header or the one specified in the app's configuration:

=over

=item * C<path>

=item * C<param>

=item * C<cgi_param>

=item * C<query_param>

=item * C<body_param>

=item * C<parameters>

=item * C<query_parameters>

=item * C<body_parameters>

=item * C<content>

=back

If you wish to get input in the original request encoding, use these instead
(note: there is no C<raw_param>):

=over

=item * C<raw_path>

=item * C<raw_parameters>

=item * C<raw_query_parameters>

=item * C<raw_body_parameters>

=item * C<raw_body> (instead of C<content>)

=back

Following methods will return decoded values if the other parts of the system
are configured to decode them:

=over

=item * C<param> - depends on JSON module (on JSON requests)

=item * C<json_param> - depends on JSON module

=item * C<json_content> - depends on JSON module

=item * C<session> - depends on session middleware

=back

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

=head1 METHODS

=head2 param

Shortcut for returning the HTTP parameters of the request with heavy amount of
dwimmery. It has two modes of operation and behaves differently for JSON and
non-JSON requests.

=over

=item

If passed with a parameter, returns the value value of a parameter with that
name from either request body or query (body is preferred). This always returns
a scalar value.

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

Since this method behaves differently based on the form of input, you're
encouraged to use other, more specific methods listed below.

=head2 query_param

Same as L</param>, but always returns parameters from query string.

=head2 body_param

Same as L</param>, but always returns parameters from body form.

=head2 json_param

Same as L</param>, but always returns parameters from JSON body.

=head2 cgi_param

CGI.pm compatible implementation of C<param> (but does not set parameters). It
is B<not recommended> to use this method, unless for some reason you have to
maintain CGI.pm compatibility. Misusing this method can lead to bugs and
security vulnerabilities.

=head2 parameters

Same as L<Plack::Request/parameters>, but the keys and values in the hash are decoded.

=head2 raw_parameters

Same as L<Plack::Request/parameters>. The hash keys and values are B<not> decoded.

=head2 query_parameters

Same as L<Plack::Request/query_parameters>, but the keys and values in the hash are decoded.

=head2 raw_query_parameters

Same as L<Plack::Request/query_parameters>, The hash keys and values are B<not> decoded.

=head2 body_parameters

Same as L<Plack::Request/body_parameters>, but the keys and values in the hash are decoded.

=head2 raw_body_parameters

Same as L<Plack::Request/body_parameters>, The hash keys and values are B<not> decoded.

=head2 content

Same as L<Plack::Request/content>, but the result is decoded.

This is the go-to method for getting the request body for string manipulation
character by character. It can be useful when you, for example, want to run a
regex on the body. Use this instead of L</raw_body>.

=head2 raw_body

Same as L<Plack::Request/raw_body>. The result is B<not> decoded.

This is the go-to method for getting the request body for string manipulation
byte by byte. An example would be deserializing the body with a custom
serializer. Use this instead of L</content>.

=head2 json_content

Returns the json-decoded body of the request or undef if the request is not
json, there is no json decoder or an error occured.

=head2 path

Same as L<Plack::Request/path>, but the result is decoded.

=head2 raw_path

Same as L<Plack::Request/path>. The result is B<not> decoded.

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

Replace all values with a hash:

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

=head2 charset

Returns the charset from the C<Content-Type> HTTP header or C<undef> if there
is none. Also checks whether the charset is supported by Encode and returns
C<undef> if it isn't.

=head2 charset_decode

Same as L<Kelp/charset_decode>, but will prefer using L</charset> to L<Kelp/charset>.

=head2 charset_encode

Encoding counterpart of L</charset_decode>. It's only useful in very narrow
scenario, so avoid using it - usually you want to encode into response's
charset, which will be an application charset.

=cut

