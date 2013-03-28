package Kelp::Response;

use Kelp::Base 'Plack::Response';

use Encode;
use Carp;
use Try::Tiny;

attr -app => sub { confess "app is required" };
attr is_rendered => 0;

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
    $self->is_rendered(1);
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

no Kelp::Base;

1;
