package CustomContext::Controller::Foo;

use Kelp::Base 'CustomContext::Controller';

sub test
{
    my ($self) = @_;

    $self->res->text;
    return ref $self;
}

sub test_template
{
    my ($self) = @_;

    $self->res->template('home');
}

sub nested_psgi
{
    my ($self) = @_;

    return [
        200,
        ['Content-Type' => 'text/plain'],
        [
            'PSGI OK'
        ],
    ];
}

1;

