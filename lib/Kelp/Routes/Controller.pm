package Kelp::Routes::Controller;

use Kelp::Base 'Kelp::Routes';

# the new Kelp::Routes does the Controller logic by itself, we just need to configure it correctly
attr rebless => 1;

1;

__END__

=pod

=head1 NAME

Kelp::Routes::Controller - Legacy routes and controller for Kelp

=head1 SYNOPSIS

    # config.pl
    # ---------
    {
        modules_init => {
            Routes => {
                router => 'Controller',
                base   => 'MyApp::Controller',
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

    sub read {
        my $self = shift;   # $self is an instance of 'MyApp::Controller::Users'
        ...
    }


=head1 DESCRIPTION

B<< This module is no longer needed, since L<Kelp::Routes> handles reblessing
by itself when configured with C<rebless>. It's only here for backward
compatibility and documentation purposes. >>

This router module reblesses a Kelp application into its own controller class.
This allows you to structure your web application in a classic object oriented
fashion, having C<$self> an instance to the current class rather than the main
web application.

You must create a main I<controller> class which inherits from Kelp.  Each
subsequent class can inherit from this class, taking advantage of any common
functionality.


=cut

