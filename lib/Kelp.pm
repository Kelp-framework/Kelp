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

# Basic attributes
attr -host => hostname;
attr -mode => $ENV{PLACK_ENV} // 'development';
attr -path => $FindBin::Bin;
attr -name => 'Kelp';

# Modules to load on startup
attr -modules => [qw/Template Logger JSON/];

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

    my @required_modules = qw(Config Routes);
    $self->load_module($_) for (
        @required_modules,
        @{ $self->modules }
    );

    $self->build();
    return $self;
}

# Override this one to add custom initializations
sub build {
}

sub load_module {
    my $self = shift;
    my $name = shift;

    # Make sure the module was not already loaded
    return if $self->{_loaded_modules}->{$name}++;

    my %args = ();
    if ( $self->can('config')
        && defined( my $c = $self->config("modules.$name") ) ) {
        %args = %$c;
    }
    my $class = Plack::Util::load_class( $name, 'Kelp::Module' );
    my $module = $class->new( app => $self );
    $module->build(%args);
    return $module;
}

#----------------------------------------------------------------
# Methods
#----------------------------------------------------------------

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

# Override this to wrap middleware arround the app
sub psgi {
    my $self = shift;
    return sub { $self->run( @_ ) }
}

sub run {
    my ( $self, $env ) = @_;

    # Create the request and response objects
    my $req = $self->req( $self->request($env) );
    my $res = $self->res( $self->response );

    # Get route matches
    my $match = $self->routes->match( $req->path, method => $req->method );

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

        # Check if the destination finction exists
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

            # Handle delayed reponse if CODE
            return $data if ref($data) eq 'CODE';
            $res->render($data) unless $res->is_rendered;
        }

        # If no data returned at all, then croak with error.
        else {
            $self->_croak(
                $route->to . " did not render for method " . $req->method );
        }

    }

    $res->finalize;
}

#----------------------------------------------------------------
# Request and Response shortcuts
#----------------------------------------------------------------
sub param { shift->req->param(@_) }

sub stash {
    my $self = shift;
    @_ ? $self->res->stash->{$_[0]} : $self->res->stash;
}

sub named {
    my $self = shift;
    @_ ? $self->req->named->{$_[0]} : $self->req->named;
}

#----------------------------------------------------------------
# Utility
#----------------------------------------------------------------

sub dump {
    my ( $self, $item, $depth ) = @_;
    $Data::Dumper::Maxdepth = $depth // 2;
    return Dumper($item);
}

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
        $self->logger->critical($message);
    }
    croak $message;
}

1;
