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
