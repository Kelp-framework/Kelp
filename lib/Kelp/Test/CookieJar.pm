package Kelp::Test::CookieJar;

use Kelp::Base;
use URI::Escape;

# Stripped-down HTTP::Cookies interface for testing purposes and proper url escaping

attr cookies => sub { {} };

sub set_cookie
{
    my ($self, undef, $name, $value) = @_;

    $self->cookies->{$name} = $value;
    return 1;
}

sub get_cookies
{
    my ($self, undef, @names) = @_;

    my %ret;

    if (@names) {
        return $self->cookies->{$names[0]}
            unless wantarray;

        return map { $self->cookies->{$_} } @names;
    }
    else {
        return $self->cookies;
    }
}

sub clear
{
    my ($self, undef, undef, $name) = @_;

    if ($name) {
        delete $self->cookies->{$name};
    }
    else {
        %{$self->cookies} = ();
    }

    return $self;
}

sub add_cookie_header
{
    my ($self, $request) = @_;

    my %c = %{$self->cookies};
    my @vals = map { uri_escape($_) . '=' . uri_escape($c{$_}) } keys %c;
    $request->header(Cookie => join '; ', @vals);

    return $request;
}

sub extract_cookies
{
    my ($self, $response) = @_;

    my @headers = split ', ', $response->header('Set-Cookie') // '';
    foreach my $header (@headers) {
        my $cookie = (split /; /, $header)[0];
        my ($name, $value) = split '=', $cookie;

        next unless defined $name && defined $value;
        $self->set_cookie(undef, uri_unescape($name), uri_unescape($value));
    }

    return $response;
}

1;

