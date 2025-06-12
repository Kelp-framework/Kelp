package Kelp::Response;

use Kelp::Base 'Plack::Response';

use Carp;
use Try::Tiny;
use Scalar::Util qw(blessed);
use HTTP::Status qw(status_message);
use Kelp::Util;

our @CARP_NOT = qw(Kelp);

attr -app => sub { croak "app is required" };
attr charset => undef;
attr rendered => 0;
attr partial => 0;

sub new
{
    my ($class, %args) = @_;
    my $self = $class->SUPER::new();
    $self->{$_} = $args{$_} for keys %args;
    return $self;
}

sub set_content_type
{
    my ($self, $type, $charset) = @_;
    $self->content_type($type);
    $self->charset($charset) if $charset;
    return $self;
}

sub charset_encode
{
    my ($self, $string) = @_;
    return Kelp::Util::charset_encode(
        Kelp::Util::effective_charset($self->charset) // $self->app->charset,
        $string,
    );
}

sub _apply_charset
{
    my ($self) = @_;
    my $charset = $self->charset;
    return unless $charset;

    my $ct = $self->content_type;

    croak 'Cannot apply charset to response without content_type'
        unless $ct;

    # content_type is actually an array, getting it in scalar context only
    # yields the actual type without charset. It will be split after setting it
    # like this
    $self->content_type("$ct; charset=$charset");
}

sub text
{
    my $self = shift;
    $self->set_content_type('text/plain', $self->charset || $self->app->charset);
    return $self;
}

sub html
{
    my $self = shift;
    $self->set_content_type('text/html', $self->charset || $self->app->charset);
    return $self;
}

sub json
{
    my $self = shift;
    $self->set_content_type('application/json', $self->charset || $self->app->charset);
    return $self;
}

sub xml
{
    my $self = shift;
    $self->set_content_type('application/xml', $self->charset || $self->app->charset);
    return $self;
}

sub finalize
{
    my $self = shift;

    $self->_apply_charset;

    my $arr = $self->SUPER::finalize(@_);
    pop @$arr if $self->partial;
    return $arr;
}

sub set_header
{
    my $self = shift;
    $self->SUPER::header(@_);
    return $self;
}

sub no_cache
{
    my $self = shift;
    $self->set_header('Cache-Control' => 'no-cache, no-store, must-revalidate');
    $self->set_header('Pragma' => 'no-cache');
    $self->set_header('Expires' => '0');
    return $self;
}

sub set_code
{
    my $self = shift;
    $self->SUPER::code(@_);
    return $self;
}

sub render
{
    my ($self, $body) = @_;

    my $method = ref $body ? '_render_ref' : '_render_nonref';
    $body = $self->$method($body);

    # Set code 200 if the code has not been set
    $self->set_code(200) unless $self->code;

    $self->body($self->charset_encode($body));
    $self->rendered(1);
    return $self;
}

# override to change how references are serialized
sub _render_ref
{
    my ($self, $body) = @_;
    my $ct = $self->content_type;

    if (!$ct || $ct =~ m{^application/json}i) {
        $self->json if !$ct;
        return $self->app->get_encoder(json => 'internal')->encode($body);
    }
    else {
        croak "Don't know how to handle reference for $ct in response (forgot to serialize?)";
    }
}

# override to change how non-references are handled
sub _render_nonref
{
    my ($self, $body) = @_;
    $self->html if !$self->content_type;

    return $body;
}

sub render_binary
{
    my ($self, $body) = @_;
    $body //= '';

    # Set code 200 if the code has not been set
    $self->set_code(200) unless $self->code;

    if (!$self->content_type) {
        croak "Content-type must be explicitly set for binaries";
    }

    $self->body($body);
    $self->rendered(1);
    return $self;
}

sub render_error
{
    my ($self, $code, $error) = @_;

    $code //= 500;
    $error //= status_message($code) // 'Error';

    $self->set_code($code);

    # Look for a template and if not found, then show a generic text
    try {
        local $SIG{__DIE__};    # Silence StackTrace
        $self->template(
            "error/$code", {
                error => $error
            }
        );
    }
    catch {
        $self->text->render("$code - $error");
    };

    return $self;
}

sub render_exception
{
    my ($self, $exception) = @_;

    # If the error is 500, do the same thing normal errors do: provide more
    # info on non-production
    return $self->render_500($exception->body)
        if $exception->code == 500;

    return $self->render_error($exception->code);
}

sub render_401
{
    $_[0]->render_error(401);
}

sub render_403
{
    $_[0]->render_error(403);
}

sub render_404
{
    $_[0]->render_error(404);
}

sub render_500
{
    my ($self, $error) = @_;

    # Do not leak information on production!
    if ($self->app->is_production) {
        return $self->render_error;
    }

    # if render_500 gets blessed object as error, stringify it
    $error = "$error" if blessed $error;
    $error //= 'No error, something is wrong';

    # at this point, error will never be in HTML, since the exception body
    # would have to be HTML itself. Try to nest it inside a template. NOTE: We
    # don't currently handle ref errors here which aren't objects
    return $self->render_error(500, $error);
}

sub redirect
{
    my $self = shift;
    $self->rendered(1);
    $self->SUPER::redirect(@_);
}

sub redirect_to
{
    my ($self, $where, $args, $code) = @_;
    my $url = $self->app->url_for($where, %$args);
    $self->redirect($url, $code);
}

sub template
{
    my ($self, $template, $vars, @rest) = @_;

    # Do we have a template module loaded?
    croak "No template module loaded"
        unless $self->app->can('template');

    # run template in current controller context
    my $output = $self->app->context->run_method('template', $template, $vars, @rest);
    $self->render($output);
}

1;

__END__

=head1 NAME

Kelp::Response - Format an HTTP response

=head1 SYNOPSIS

Examples of how to use this module make a lot more sense when shown inside
route definitions. Note that in the below examples C<$self-E<gt>res>
is an instance of C<Kelp::Response>:

    # Render simple text
    sub text {
        my $self = shift;
        $self->res->text->render("It works!");
    }

    # Render advanced HTML
    sub html {
        my $self = shift;
        $self->res->html->render("<h1>It works!</h1>");
    }

    # Render a mysterious JSON structure
    sub json {
        my $self = shift;
        $self->res->json->render({ why => 'no' });
    }

    # Render the stock 404
    sub missing {
        my $self = shift;
        $self->res->render_404;
    }

    # Render a template
    sub view {
        my $self = shift;
        $self->res->template('view.tt', { name => 'Rick James' });
    }

=head1 DESCRIPTION

The L<PSGI> specification requires that each route returns an array with status
code, headers and body. L<Plack::Response> already provides many useful methods
that deal with that. This module extends C<Plack::Response> to add the tools we
need to write graceful PSGI compliant responses. Some methods return C<$self>,
which makes them easy to chain.

=head1 ATTRIBUTES

=head2 app

A reference to the Kelp application. This will always be the real application,
not the reblessed controller.

=head2 charset

The charset to be used in response. Will be glued to C<Content-Type> header
just before the response is finalized.

NOTE: charset will be glued regardless of it having any sense with a given
C<Content-Type>, and will override any charset set explicitly through
L</set_content_type> - use with caution.

=head2 rendered

Tells if the response has been rendered. This attribute is used internally and
unless you know what you're doing, we recommend that you do not use it.

=head2 partial

Sets partial response. If this attribute is set to a true value, it will cause
C<finalize> to return the HTTP status code and headers, but not the body. This is
convenient if you intend to stream your content. In the following example, we
set C<partial> to 1 and use C<finalize> to get a C<writer> object for streaming.

    sub stream {
        my $self = shift;
        return sub {
            my $responder = shift;

            # Stream JSON
            $self->res->set_code(200)->json->partial(1);

            # finalize will now return only the status code and headers
            my $writer = $responder->($self->res->finalize);

            # Stream JSON body using the writer object
            for (1 .. 30) {
                $writer->write(qq|{"id":$_}\n|);
                sleep 1;
            }

            # Close the writer
            $writer->close;
        };
    }

For more information on how to stream, see the
L<PSGI/Delayed-Response-and-Streaming-Body> docs.

=head1 METHODS

=head2 render

This method tries to act smart, without being a control freak. It will fill out
the blanks, unless they were previously filled out by someone else. Here is what
is does:

=over

=item

If the response code was not previously set, this method will set it to 200.

=item

If no content-type is previously set, C<render> will set is based on the type
of the data rendered. If it's a reference, then the content-type will be set to
C<application/json>, otherwise it will be set to C<text/html>.

    # Will set the content-type to json
    $res->render({ numbers => [1, 2, 3] });

=item

Last, the data will be encoded with the charset from L</charset> or the one
specified by the app - see L<Kelp/charset>. Any string you pass here should not
already be encoded, unless your application has its charset set to undef.

=back

=head2 set_content_type

Sets the content type of the response and returns C<$self>.

    # Inside a route definition
    $self->res->set_content_type('image/png');

An optional second argument can be passed, which will be used for C<charset>
part of C<Content-Type> (will set L</charset> field).

=head2 text, html, json, xml

These methods are shortcuts for C<set_content_type> with the corresponding type.
All of them set the content-type header and return C<$self> so they can be
chained.

    $self->res->text->render("word");
    $self->res->html->render("<p>word</p>");
    $self->res->json->render({ word => \1 });

NOTE: These methods will also call L</charset> and set it to application's
charset (unless it was previously set).

=head2 set_header

Sets response headers. This is a wrapper around L<Plack::Response/header>, which
returns C<$self> to allow for chaining.

    $self->res->set_header('X-Something' => 'Value')->text->render("Hello");

=head2 no_cache

A convenience method that sets several response headers instructing most
browsers to not cache the response.

    $self->res->no_cache->json->render({ epoch => time });

The above response will contain headers that disable caching.

=head2 set_code

Set the response code.

    $self->res->set_code(401)->render("Access denied");

=head2 render_binary

Render binary data such as byte streams, files, images, etc. You must
explicitly set the content_type before that. Will not encode the content into
any charset.

    use Kelp::Less;

    get '/image/:name' => sub {
        my $content = Path::Tiny::path("$name.jpg")->slurp_raw;
        res->set_content_type('image/jpeg')->render_binary($content);

        # the same, but probably more effective way (PSGI-server dependent)
        open my $handle, "<:raw", "$name.png"
            or die "cannot open $name: $!";
        res->set_content_type('image/png')->render_binary($handle);
    };

=head2 render_error

    $self->render_error($code, $error)

Renders the specified return code and an error message. This sub will first look
for this error template C<error/$code>, before displaying a plain page with the
error text.

    $self->res->render_error(510, "Not Extended");

The above code will look for a template named C<views/errors/510.tt>, and if not
found it will render this message:

    510 - Not Extended

A return code of 510 will also be set.

If a standard error message is to be used, it may be skipped - will be pulled
from L<HTTP::Status>.

=head2 render_404

A convenience method that sets code 404 and returns "File Not Found".

    sub some_route {
        if ( not $self->req->param('ok') ) {
            return $self->res->render_404;
        }
    }

If your application's tone is overly friendly or humorous, you will want to create a
custom 404 page. The best way to do this is to design your own C<404.tt> template and
put it in the C<views/error>.

=head2 render_500

    $self->render_500($optional_error)

Renders the 500 error page. Designing your own 500 page is possible by adding file
C<500.tt> in C<views/error>.

Keep in mind C<$optional_error> will not show in C<deployment> mode, and
instead stock error message will be displayed.

=head2 redirect_to

Redirects the client to a named route or to a given url. In case the route is passed by
name, a hash reference with the needed arguments can be passed after the route's name.
As a third optional argument, you can enter the desired response code:

    $self->redirect_to( '/example' );
    $self->redirect_to( 'catalogue' );
    $self->redirect_to( 'catalogue', { id => 243 });
    $self->redirect_to( 'other', {}, 303 );

This method attempts to build the Kelp route by name, so if you want to just
redirect to an url it's better to use L<Plack::Response/redirect>.

=head2 template

This method renders a template. The template should be previously configured by
you and included via a module. See L<Kelp::Module::Template> for a template
module.

    sub some_route {
        my $self = shift;
        $self->res->template('home.tt', { login => 'user' });
    }

=head2 charset_encode

Shortcut method, which encodes a string using the L</charset> or L<Kelp/charset>.

