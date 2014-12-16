package Kelp::Module::Logger;

use Kelp::Base 'Kelp::Module';

use File::Path;
use Carp;
use Log::Dispatch;
use Data::Dumper;

sub _logger {
    my ( $self, %args ) = @_;
    Log::Dispatch->new(%args);
}

sub build {
    my ( $self, %args ) = @_;
    my $logger = $self->{logger} = $self->_logger(%args);

    # Register a few levels
    my @levels_to_register = qw/debug info error/;

    # Build the registration hash
    my %LEVELS = map {
        my $level = $_;
        $level => sub {
            my $app = shift;
            $self->message( $level, @_ );
        };
    } @levels_to_register;

    # Register the log levels
    $self->register(%LEVELS);

    # Also register the message method as 'logger'
    $self->register( logger => sub {
        shift;
        $self->message(@_);
    });
}

sub message {
    my ( $self, $level, @messages ) = @_;
    my @a    = localtime(time);
    my $date = sprintf(
        "%4i-%02i-%02i %02i:%02i:%02i",
        $a[5] + 1900,
        $a[4] + 1,
        $a[3], $a[2], $a[1], $a[0]
    );

    for (@messages) {
        $self->{logger}->log(
            level   => $level,
            message => sprintf( '%s - %s - %s',
                $date, $level, ref($_) ? Dumper($_) : $_ )
        );
    }
}

1;

__END__

=pod

=head1 NAME

Kelp::Module::Logger - Logger for Kelp applications

=head1 SYNOPSIS

    # conf/config.pl
    {
        modules => ['Logger'],
        modules_init => {
            Logger => {
                outputs => [
                    [ 'Screen',  min_level => 'debug', newline => 1 ],
                ]
            },
        },
    }

   # lib/MyApp.pm
   sub run {
        my $self = shift;
        my $app = $self->SUPER::run(@_);
        ...;
        $app->info('Kelp is ready to rock!');
        return $app;
   }


=head1 DESCRIPTION

This module provides an log interface for Kelp web application. It uses
L<Log::Dispatcher> as underlying logging module.

=head1 REGISTERED METHODS

=head2 debug

=head2 info

=head2 error

=cut
