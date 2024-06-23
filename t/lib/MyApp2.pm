package MyApp2;
use Kelp::Base 'Kelp';

sub build
{
    my $self = shift;
    my $r = $self->routes;
    $r->add("/test_inherit", "bar#test_inherit");
    $r->add("/test_module", "bar#test_module");
    $r->add("/test_template", "bar#test_template");
    $r->add("/test_res_template", "bar#test_res_template");

    $self->context->controller->build;
    $self->context->controller('bar')->build;
}

1;

