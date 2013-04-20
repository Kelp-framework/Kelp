package MyApp::Routes;

sub greet {
    my ( $self, $name ) = @_;
    return "OK $name";
}

1;
