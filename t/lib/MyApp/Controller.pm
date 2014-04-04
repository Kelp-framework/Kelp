package MyApp::Controller;
use parent 'MyApp';

sub blessed {
    ref $_[0];
}

sub attrib {
    my $self = shift;
    $self->path;
}

1;
