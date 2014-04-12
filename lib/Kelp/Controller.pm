package Kelp::Controller;

use Kelp::Base 'Kelp';
use Carp;

attr app => sub { croak 'No app defined' };

sub new {
    my $class = shift;

    my $self = bless {}, ref($class) || $class;
    $self->_init(@_);

    $self->app or croak "No app instance supplied";

    return $self;
}

sub _init {
    my $self = shift;

    while (@_) {
        my ($method, $val) = splice @_, 0, 2;
        $self->$method(ref $val eq 'ARRAY' ? @$val : $val);
    }
}

sub DESTROY {}

sub AUTOLOAD {
    my $self = shift;

    my $name = our $AUTOLOAD;
    $name =~ s/^.*:://;

    ref $self or croak "Unknown method '$name'";

    $self->app->$name(@_); 
}

1;
