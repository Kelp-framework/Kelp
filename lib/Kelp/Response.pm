package Kelp::Response;

use Kelp::Base 'Plack::Response';

use Encode;
use Carp;
use Try::Tiny;

attr -app => sub { confess "app is required" };
attr rendered => 0;
attr partial  => 0;

sub new {
    my ( $class, %args ) = @_;
    my $self = $class->SUPER::new();
    $self->{$_} = $args{$_} for keys %args;
    return $self;
}

sub set_content_type {
    $_[0]->content_type( $_[1] );
    return $_[0];
}

sub text {
    $_[0]->set_content_type( 'text/plain; charset=' . $_[0]->app->charset );
}

sub html {
    $_[0]->set_content_type( 'text/html; charset=' . $_[0]->app->charset );
}

sub json {
    $_[0]->set_content_type('application/json');
}

sub xml {
    $_[0]->set_content_type('application/xml');
}

sub finalize {
    my $self = shift;
    my $arr  = $self->SUPER::finalize(@_);
    pop @$arr if $self->partial;
    return $arr;
}

sub set_header {
    my $self = shift;
    $self->SUPER::header(@_);
    return $self;
}

sub no_cache {
    my $self = shift;
    $self->set_header( 'Cache-Control' => 'no-cache, no-store, must-revalidate' );
    $self->set_header( 'Pragma'        => 'no-cache' );
    $self->set_header( 'Expires'       => '0' );
    return $self;
}

sub set_code {
    my $self = shift;
    $self->SUPER::code(@_);
    return $self;
}

sub render {
    my $self = shift;
    my $body = shift // '';

    # Set code 200 if the code has not been set
    $self->set_code(200) unless $self->code;

    # If no content_type is set, then set it based on
    # the type of $body - JSON or HTML.
    unless ( $self->content_type ) {
        ref( $body ) ? $self->json : $self->html;
    }

    # If the content has been determined as JSON, then encode it
    if ( $self->content_type eq 'application/json' ) {
        confess "No JSON decoder" unless $self->app->can('json');
        confess "Data must be a reference" unless ref($body);
        $body = $self->app->json->encode($body);
    }

    $self->body( encode( $self->app->charset, $body ) );
    $self->rendered(1);
    return $self;
}

sub render_404 {
    $_[0]->set_code(404)->render("404 - File Not Found");
}

sub render_500 {
    $_[0]->set_code(500)->render("500 - Server Error");
}

sub redirect_to {
    my ( $self, $where, $args, $code ) = @_;
    my $url = $self->app->url_for($where, %$args);
    $self->redirect( $url, $code );
}

sub template {
    my ( $self, $template, $vars, @rest ) = @_;

    # Add the app object for convenience
    $vars->{app} = $self->app;

    # Do we have a template module loaded?
    croak "No template module loaded"
      unless $self->app->can('template');

    my $output = $self->app->template( $template, $vars, @rest );
    $self->render($output);
}

1;

__END__

=pod

=head1 NAME

Kelp::Response - Format an HTTP response

=head1 SYNOPSIS

Examples of route definitions make a lot more sense when showing how to use this
module. Note that in the below examples C<$self-E<gt>res> is an instance of
C<Kelp::Response>:

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
        $self->res->template('view.tt', { name => 'Rick James' } );
    }

=head1 DESCRIPTION

The L<PSGI> specification requires that each route returns an array with status
code, headers and body. C<Plack::Response> already provides many useful methods
that deal with that. This module extends C<Plack::Response> to add the tools we
need to write graceful PSGI compliant responses. Some methods return C<$self>,
which makes them easy to chain.

=head1 ATTRIBUTES

=head2 rendered

Tells if the response has been rendered. This attribute is used internally and
unless you know what you're doing, we recommend that you do not use it.

=head2 partial

Sets partial response. If this attribute is set to a true value, it will cause
C<finalize> to return the HTTP status code and headers, but not the body. This is
convenient if you intend to stream your content. It the following example, we
set C<partial> to 1 and use C<finalize> to get a C<writer> object for streaming.

    sub stream {
        my $self = shift;
        return sub {
            my $responder = shift;

            # Stream JSON
            $self->res->set_code(200)->json->partial(1);

            # finalize will now return only the status code and headers
            my $writer = $responder->( $self->res->finalize );

            # Stream JSON body using the writer object
            for ( 1 .. 30 ) {
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

=cut

=item

If no content-type is previously set, C<render> will set is based on the type of
the data rendered. If it's a reference, then the content-type will be set to
C<application/json>, otherwise it will be set to C<text/html>.

    # Will set the content-type to json
    $res->render( { numbers => [ 1, 2, 3 ] } );

=cut

=item

Last, the data will be encoded with the charset specified by the app.

=cut

=back

=head2 set_content_type

Sets the content type of the response and returns C<$self>.

    # Inside a route definition
    $self->res->set_content_type('image/png');

=head2 text, html, json, xml

These methods are shortcuts for C<set_content_type> with the corresponding type.
All of them set the content-type header and return C<$self> so they can be
chained.

    $self->res->text->render("word");
    $self->res->html->render("<p>word</p>");
    $self->res->json->render({ word => \1 });

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

=head2 render_404

A convenience method that sets code 404 and returns "File Not Found".

    sub some_route {
        if ( not $self->req->param('ok') ) {
            return $self->res->render_404;
        }
    }

If your application's tone is overly friendly or humorous, you will want to create a
custom 404 page. The best way to do this is to subclass this module into your
own class, for example C<MyApp::Response>. Then override the C<render_404> method.

    package MyApp::Response;
    use parent 'Kelp::Response';

    sub render_404 {
        my $self = shift;
        $self->set_code(404)->template('errors/404.tt');
    }

You'll have to override the L<Kelp/response> method in your main module too, in
order to instruct it to use your new class:

    package MyApp;
    use parent 'Kelp';

    sub response {
        my $self = shift;
        return MyApp::Response->new( app => $self );
    }

=head2 render_500

Renders the stock "500 - Server Error" message. See L</render_404> for examples
on how to customize it.

=head2 template

This method renders a template. The template should be previously configured by
you and included via a module. See L<Kelp::Module::Template> for a template
module.

    sub some_route {
        my $self = shift;
        $self->res->template('home.tt', { login => 'user' });
    }

=cut
