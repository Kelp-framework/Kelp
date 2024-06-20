package Kelp::Module::Config::Injected;
use Kelp::Base 'Kelp::Module::Config';

sub load
{
    return {
        injected => 1
    };
}

1;

