package Kelp::Controller;

use Carp;
use Kelp::Base;

use parent qw/ Kelp /;

attr app => sub { croak 'No app defined' };

sub new {
    my $class = shift;
    
    my $self = $class->SUPER::new();
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

1;
