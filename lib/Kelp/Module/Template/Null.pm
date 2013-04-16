package Kelp::Module::Template::Null;
use Kelp::Base 'Kelp::Module::Template';
use Plack::Util;

attr ext => 'null';

sub build_engine {
    my ( $self, %args ) = @_;
    Plack::Util::inline_object( render => sub { "All the ducks" } );
}

sub render {
    my ( $self, $template, $vars, @rest ) = @_;
    $self->engine->render();
}

1;
