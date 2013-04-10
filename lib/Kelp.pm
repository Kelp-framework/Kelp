package Kelp;

use Kelp::Base;

use Carp;
use FindBin;
use Encode;
use Try::Tiny;
use Data::Dumper;
use Sys::Hostname;
use Plack::Util;
use Kelp::Request;
use Kelp::Response;

our $VERSION = 0.10;

# Basic attributes
attr -host => hostname;
attr -mode => $ENV{KELP_ENV} // $ENV{PLACK_ENV} // 'development';
attr -path => $FindBin::Bin;
attr -name => sub { ( ref( $_[0] ) =~ /(\w+)$/ ) ? $1 : 'Noname' };

# The charset is UTF-8 unless otherwise instructed
attr -charset => sub {
    $_[0]->config("charset") // 'UTF-8';
};

# Each route's request an response objects will
# be put here:
attr req => undef;
attr res => undef;

# Initialization
sub new {
    my $self = shift->SUPER::new(@_);

    # Always load these modules
    $self->load_module($_) for ( qw/Config Routes/ );

    # Load the modules from the config
    if ( defined( my $modules = $self->config('modules') ) ) {
        $self->load_module($_) for @$modules;
    }

    $self->build();
    return $self;
}

sub load_module {
    my ( $self, $name ) = @_;

    # Make sure the module was not already loaded
    return if $self->{_loaded_modules}->{$name}++;

    my $class = Plack::Util::load_class( $name, 'Kelp::Module' );
    my $module = $class->new( app => $self );

    # When loading the Config module itself, we don't have
    # access to $self->config yet. This is why we check if
    # config is available, and if it is, then we pull the
    # initialization hash.
    my $args = {};
    if ( $self->can('config') ) {
        $args = $self->config("modules_init.$name") // {};
    }

    $module->build(%$args);
    return $module;
}

# Override this one to add custom initializations
sub build {
}

# Override to use a custom request object
sub request {
    my ( $self, $env ) = @_;
    return Kelp::Request->new( app => $self, env => $env );
}

# Override to use a custom response object
sub response {
    my $self = shift;
    return Kelp::Response->new( app => $self );
}

# Override to manipulate the end response
sub before_render {
    my $self = shift;
    $self->res->header('X-Framework' => 'Perl Kelp');
}

# Override this to wrap more middleware around the app
sub run {
    my $self = shift;
    my $app = sub { $self->psgi(@_) };

    # Add middleware
    if ( defined( my $middleware = $self->config('middleware') ) ) {
        for my $class (@$middleware) {

            # Make sure the middleware was not already loaded
            next if $self->{_loaded_middleware}->{$class}++;

            my $mw = Plack::Util::load_class($class, 'Plack::Middleware');
            my $args = $self->config("middleware_init.$class") // {};
            $app = $mw->wrap( $app, %$args );
        }
    }

    return $app;
}

sub psgi {
    my ( $self, $env ) = @_;

    # Create the request and response objects
    my $req = $self->req( $self->request($env) );
    my $res = $self->res( $self->response );

    # Get route matches
    my $match = $self->routes->match( $req->path, $req->method );

    # None found? Show 404 ...
    if ( !@$match ) {
        $res->render_404;
        return $res->finalize;
    }

    # Go over the entire route chain
    for my $route (@$match) {
        my $to = $route->to;

        # Check if the destination is valid
        if ( ref($to) && ref($to) ne 'CODE' || !$to ) {
            $self->_croak('Invalid destination for ' . $req->path);
        }

        # Check if the destination function exists
        if ( !ref($to) && !exists &$to ) {
            $self->_croak(sprintf('Route not found %s for %s', $to, $req->path));
        }

        # Log info about the route
        if ( $self->can('logger') ) {
            $self->logger(
                'info',
                sprintf( "%s - %s %s - %s",
                    $req->address, $req->method, $req->path, $to )
            );
        }

        # Eval the destination code
        my $code = ref $to eq 'CODE' ? $to : \&{$to};
        $req->named( $route->named );

        my $data;
        try {
            $data = $code->($self, @{ $route->param });
        }
        catch {
            $self->_croak($_);
        };

        # Is it a bridge? Bridges must return a true value
        # to allow the rest of the routes to run.
        if ( $route->bridge ) {
            if ( !$data ) {
                $res->render_404 unless $res->code;
                last;
            }
            next;
        }

        # If the route returned something, then analyze it and render it
        if ( defined $data ) {

            # Handle delayed response if CODE
            return $data if ref($data) eq 'CODE';
            $res->render($data) unless $res->is_rendered;
        }

        # If no data returned at all, then croak with error.
        else {
            $self->_croak(
                $route->to . " did not render for method " . $req->method );
        }

    }

    $self->before_render;
    $res->finalize;
}

#----------------------------------------------------------------
# Request and Response shortcuts
#----------------------------------------------------------------
sub param { shift->req->param(@_) }

sub stash {
    my $self = shift;
    @_ ? $self->req->stash->{$_[0]} : $self->req->stash;
}

sub named {
    my $self = shift;
    @_ ? $self->req->named->{$_[0]} : $self->req->named;
}

#----------------------------------------------------------------
# Utility
#----------------------------------------------------------------

sub url_for {
    my ( $self, $name, @args ) = @_;
    my $result = $name;
    try { $result = $self->routes->url( $name, @args ) };
    return $result;
}

sub abs_url {
    my ( $self, $name, @args ) = @_;
    my $url = $self->url_for( $name, @args );
    return URI->new_abs( $url, $self->config('app_url') )->as_string;
}

# Internal

sub _croak {
    my $self = shift;
    my $message = shift // return;
    if ( $self->can('logger') ) {
        $self->logger('critical', $message);
    }
    croak $message;
}

1;

__END__

=pod

=head1 NAME

Kelp - A web framework light, yet rich in nutrients.

=head1 MANUAL

=head2 L<Kelp::Manual::Main>

Main manual.

=head2 L<Kelp::Manual::Less>

Information on using C<Kelp::Less>.

=head1 SUPPORT

=over

=item * GitHub: https://github.com/naturalist/kelp

=item * Mailing list: https://groups.google.com/forum/?fromgroups#!forum/perl-kelp

=back

=head1 AUTHOR

Stefan Geneshky - minimal@cpan.org

=head1 LICENSE

This module and all the modules in this package are governed by the same license
as Perl itself.

=cut
