package Kelp::Module::Plus;
use Kelp::Base 'Kelp::Module';

sub build
{
    my ($self, %args) = @_;
    $self->register(plus => sub { $_[1] + $args{number} });
}

1;

