package Kelp::Module::Template::Null;
use Kelp::Base 'Kelp::Module::Template';

attr ext => undef;

sub build_engine
{
    return undef;
}

sub render
{
    return '';
}

1;

# This is a stub template module which may be used as a placeholder for a
# future template module.

