package MyApp2;
use Kelp::Base 'Kelp';

sub build
{
    my $self = shift;
    my $r = $self->routes;
    $r->add("/blessed", "blessed");
    $r->add("/blessed_bar", "Bar::blessed");
    $r->add("/blessed_bar2", "bar#blessed");
    $r->add("/test_inherit", "bar#test_inherit");
    $r->add("/test_module", "bar#test_module");
    $r->add("/test_template", "bar#test_template");
    $r->add("/test_res_template", "bar#test_res_template");
}

1;

