package Kelp::Module;

use Kelp::Base;
use Carp;

attr -app  => sub { die "app is required" };

sub new {
    my $self = shift->SUPER::new(@_);
    $self->app;
    return $self;
}

# Override this to register items
sub build {
    my ( $self, %args ) = @_;
}

sub register {
    my ( $self, %items ) = @_;
    while ( my ( $name, $item ) = each(%items) ) {
        no strict 'refs';
        no warnings 'redefine';

        my $app  = ref $self->app;
        my $glob = "${app}::$name";

        # Manually check if the glob is being redefined
        if ( !$ENV{KELP_REDEFINE} && $self->app->can($name) ) {
            croak "Redefining of $glob not allowed";
        }

        if ( ref $item eq 'CODE' ) {
            *{$glob} = $item;
        }
        else {
            $self->app->{$name} = $item;
            *{$glob} = sub { $_[0]->{$name} }
        }
    }
}

1;

__END__

=pod

=head1 NAME

Kelp::Module - Base class for Kelp modules

=head1 SYNOPSIS

    package Kelp::Module::MyModule;
    use parent 'Kelp::Module';

    sub build {
        my ( $self, %args ) = @_;
        $self->register( greet => sub { print "Hi there." } );
    }

=head1 DESCRIPTION

Provides the base class for creating Kelp modules. Creating a Kelp module means
extending this class and overriding the C<build> method.
Kelp modules usually C<register> a new method into the web application.

=head2 Registering methods

Modules use the L</register> method to register new methods into the underlying
web application. All the registrations are done in the L</build> subroutine.
All types of values can be registered and then accessed as a read-only attribute
from the web app. The simplest thing you can register is a scalar value:

First...

    # lib/Kelp/Module/Month.pm
    package Kelp::Module::Month;
    use Kelp::Base 'Kelp::Module';

    sub build {
        my ( $self, %args ) = @_;
        $self->register( month => 'October' );
    }

Then ...

    # lib/MyApp.pm
    package MyApp;
    use parent 'Kelp';

    sub build {
        $self->load_module("Month");
    }

    sub is_it_october_yet {
        my $self = shift;
        if ( $self->month eq 'October' ) {
            return "It is October";
        }
        return "Not yet.";
    }

The above example doesn't do anything meaningful, but it's a good
way to show how to create and use Kelp modules. Pay attention to the next
example, as it will show you how to register an anonymous subroutine:

    package Kelp::Module::Date;
    use Kelp::Base 'Kelp::Module';
    use DateTime;

    sub build {
        my ( $self, %args ) = @_;
        $self->register(
            date => sub {
                return DateTime->from_epoch( epoch => time );
            }
        );
    }

Now, each time you use C<$self-E<gt>date> in the web application, you will create
a new C<DateTime> object for the current time.

It is more practical to register an already created object. Consider this
example, which uses C<Redis>, initializes an instance of it and registers it as
a method in the web app:

    package Kelp::Module::Redis;
    use Kelp::Base 'Kelp::Module';
    use Redis;

    sub build {
        my ( $self, %args ) = @_;
        my $redis = Redis->new(%args);
        $self->register( redis => $redis );
    }

=head2 Passing arguments to your module

The arguments for all modules are taken from the configuration. If you want to
pass arguments for your C<Redis> module (example above), you will have to have a
structure in your config, similar to this:

Example of C<conf/myapp.conf>:

    {
        # Load module Redis on start
        modules      => ['Redis'],
        modules_init => {
            Redis => {
                server   => '192.168.0.1:6379',
                encoding => 'UTF-8',
                password => 'boo'
            }
        }
    };

The hash specified by C<Redis> will be sent as C<%args> in the C<build> method
of the module.

=head1 METHODS

=head2 build

C<build( %args )>

Each module must override this one in order to register new methods. The
C<%args> hash will be taken from the configuration.

=head2 register

C<register( %items )>

Registers one or many methods into the web application.

    $self->register(
        json => JSON->new,
        yaml => YAML->new
    );

=cut
