package MyApp2::Controller::Bar;
use Kelp::Base 'MyApp2::Controller';

sub naughty_secret { "I control the Bar" }

sub test_inherit { "OK" }

sub test_template {
    return $_[0]->template('0');
}

1;

