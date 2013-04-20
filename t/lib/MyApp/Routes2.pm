package MyApp::Routes2;

sub goodbye {
    my ( $self, $name ) = @_;
    return "BYE $name";
}

1;
