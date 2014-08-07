package Kelp::Module::Logger::Simple;
use Kelp::Base 'Kelp::Module::Logger';
use Plack::Util;

sub _logger {
    my ( $self, %args ) = @_;
    return $self->SUPER::_logger(
        outputs => [
            [
                'Screen',
                min_level => $args{min_level} // 'debug',
                newline   => 1,
                stderr    => 1
            ]
        ]
    );
}

1;

__END__

=pod

=head1 TITLE

Kelp::Module::Logger::Simple

=head1 SYNOPSIS

    use Kelp::Less;

    module 'Logger::Simple', min_level => 'error';

    ...

=head1 DESCRIPTION

A very simple logger that dumps everything to STDERR


=cut

1;
