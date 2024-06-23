package MyApp2::Controller;
use Kelp::Base 'MyApp2';

sub blessed { ref shift }

# Access to modules
sub test_module { shift->config('charset') }

sub build
{
    my $self = shift;
    my $r = $self->routes;

    $r->add("/blessed", "blessed");
}

1;

