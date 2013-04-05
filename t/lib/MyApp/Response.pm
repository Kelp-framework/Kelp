package MyApp::Response;
use Kelp::Base 'Kelp::Response';

sub render_404 {
    my $self = shift;
    $self->set_code(404)->text->render("NO");
}


1;
