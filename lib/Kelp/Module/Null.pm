package Kelp::Module::Null;
use Kelp::Base 'Kelp::Module';

sub build
{
    my ($self, %args) = @_;
}

1;

__END__

=pod

=head1 NAME

Kelp::Module::Null - A module placeholder

=head1 SYNOPSIS

    modules => [qw(Null)],
    modules_init => {
        Null => {
            val1 => 1,
            val2 => 2,
            whatever => "it won't use it anyway",
        },
    },

=head1 DESCRIPTION

This is a stub module which may be used as a placeholder for a future module.

