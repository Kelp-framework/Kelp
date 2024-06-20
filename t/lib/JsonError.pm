package JsonError;
use Kelp::Base 'Kelp';

sub build
{
    my $self = shift;
    my $r = $self->routes;

    $r->add(
        "/json",
        sub {
            return {
                key => sub { }
            };
        }
    );

    $r->add(
        "/forced-json",
        sub {
            my $self = shift;

            $self->res->json;
            return {
                key => sub { }
            };
        }
    );
}

1;
