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

__END__

=pod

=head1 NAME

Kelp::Module::Template::Null - A template module placeholder

=head1 SYNOPSIS

    modules => [qw(Template::Null)],
    modules_init => {
        Template::Null => {
            val1 => 1,
            val2 => 2,
            whatever => "it won't use it anyway",
        },
    },

=head1 DESCRIPTION

This is a stub template module which may be used as a placeholder for a future
template module.

