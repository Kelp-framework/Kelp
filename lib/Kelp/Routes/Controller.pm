package Kelp::Routes::Controller;

use Kelp::Base 'Kelp::Routes';
use Kelp::Controller;
use Carp;

sub dispatch {
    my $self = shift;
    my $app = shift or croak "no app supplied";
    my $match = shift or croak "no route pattern instance supplied";

    my $to = $match->to or croak 'No destination defined';

    return $self->SUPER::dispatch($match, $app) if ref $to;

    my ($controller_class, $action) = ($to =~ /^(.+)::(\w+)$/)
        or croak "Invalid controller '$to'";

    $controller_class = 'Kelp::Controller' if ref($app) eq $controller_class;

    my $controller = $controller_class->new(app => $app);
    return $controller->$action(@{ $match->param });
}


1;
