package Kelp::Module::Logger::Simple;
use Kelp::Base 'Kelp::Module::Logger';
use Plack::Util;

sub _logger
{
    my ($self, %args) = @_;
    return $self->SUPER::_logger(
        outputs => [
            [
                'Screen',
                min_level => $args{min_level} // 'debug',
                newline => 1,
                stderr => !$args{stdout},
            ]
        ]
    );
}

1;

__END__

=pod

=head1 NAME

Kelp::Module::Logger::Simple - Simple log to standard output

=head1 SYNOPSIS

    use Kelp::Less;

    module 'Logger::Simple', min_level => 'error', stdout => 1;

    ...

=head1 DESCRIPTION

A very simple logger that dumps everything to C<STDERR> or C<STDOUT> if C<<
stdout => 1 >> was configured.

=cut

