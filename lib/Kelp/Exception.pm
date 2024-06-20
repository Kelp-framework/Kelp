package Kelp::Exception;

use Kelp::Base;

use Carp;

attr -code => sub { croak 'code is required' };

attr body => undef;

sub new
{
    my ($class, $code, %params) = @_;

    croak 'Kelp::Exception can only accept 4XX or 5XX codes'
        unless defined $code && $code =~ /^[45]\d\d$/;

    $params{code} = $code;
    return $class->SUPER::new(%params);
}

sub throw
{
    my $class = shift;
    my $ex = $class->new(@_);
    die $ex;
}

1;

__END__

=pod

=head1 NAME

Kelp::Exception - Tiny HTTP exceptions

=head1 SYNOPSIS

    # will log the body to 'error' level logger
    Kelp::Exception->throw(400, body => 'The request was malformed and got aborted');

    # will only show an error page with the code
    Kelp::Exception->throw(410);

    # code is optional - 500 by default
    Kelp::Exception->throw;

=head1 DESCRIPTION

This module offers a fine-grained control of what the user sees when an
exception occurs. Generally, this could also be done by setting the
result code manually, but that requires passing the Kelp instance around and
does not immediately end the handling code. Exceptions are a way to end route
handler execution from deep within the call stack.

This implementation is very incomplete and can only handle 4XX and 5XX status
codes, meaning that you can't do redirects and normal responses like this. It
also tries to maintain some degree of compatibility with L<HTTP::Exception>
without its complexity.

=head1 ATTRIBUTES

=head2 code

HTTP status code. Only possible are 5XX and 4XX.

Readonly. Required.

=head2 body

Body of the exception - can be anything that can be serialized and if passed
will cause the application to log it on error level.

Content type and status string for the response will be set accordingly. Will
render HTML in template and plaintext if there is no template (as usual errors do).

=head1 METHODS

=head2 throw

    # both do exactly the same
    Kelp::Exception->throw(...);
    die Kelp::Exception->new(...);

Same as simply constructing and calling die on an object.

=cut

