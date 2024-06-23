package MyApp2::Controller::Bar;
use Kelp::Base 'MyApp2::Controller';

sub naughty_secret { "I control the Bar" }

sub test_inherit { "OK" }

sub test_template
{
    return $_[0]->template('0');
}

sub test_res_template
{
    $_[0]->res->template('0');
}

sub before_finalize
{
    my $self = shift;
    $self->res->header('X-Controller' => 'Bar');
}

1;

