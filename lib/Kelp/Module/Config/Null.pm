package Kelp::Module::Config::Null;
use Kelp::Base 'Kelp::Module::Config';

attr ext => 'null';

sub load {
    return {
        injected => 1
    };
}

1;
