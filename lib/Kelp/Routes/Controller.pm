package Kelp::Routes::Controller;

use Kelp::Base 'Kelp::Routes';
use Carp;

sub dispatch {
    my $self = shift;
    my $app = shift or croak "no app supplied";
    my $match = shift or croak "no route pattern instance supplied";

    my $to = $match->to or croak 'No destination defined';

    return $self->SUPER::dispatch($match, $app) if ref $to;

    my ($controller_class, $action) = ($to =~ /^(.+)::(\w+)$/)
        or croak "Invalid controller '$to'";

    my $controller = $app->_clone($controller_class);
    return $controller->$action(@{ $match->param });
}


1;

__END__

=pod

=head1 NAME

Kelp::Routes::Controller - Routes and controller for Kelp

=head1 SYNOPSIS

    # config.pl
    # ---------
    {
        modules_init => {
            Routes => {
                base   => 'MyApp::Controller',
                router => 'Controller'
            }
        }
    }

    # MyApp/Controller.pm
    # -------------------
    package MyApp::Controller;
    use Kelp::Base 'MyApp';

    sub shared_method {
        my $self = shift;   # $self is an instance of 'MyApp::Controller'
        ...
    }


    # MyApp/Controller/Users.pm
    # -------------------------
    package MyApp::Controller::Users;
    use Kelp::Base 'MyApp::Controller';

    my read {
        my $self = shift;   # $self is an instance of 'MyApp::Controller::Users'
        ...
    }


=head1 DESCRIPTION

This router module reblesses a Kelp application into its own controller class.
This allows you to structure your web application in a classic object oriented
fashion, having C<$self> an instance to the current class rather than the main
web application.

You must create a main I<controller> class which inherits from Kelp.  Each
subsequent class can inherit from this class, taking advantage of any common
functionality.


=cut
