package Kelp::Module::Logger;

use Kelp::Base 'Kelp::Module';

use File::Path;
use Carp;
use Log::Dispatch;

sub build {
    my ( $self, %args ) = @_;
    my $logger = $self->{logger} = Log::Dispatch->new(%args);

    # Register a few levels
    my @levels_to_register = qw/debug info error/;

    # Build the registration hash
    my %LEVELS = map {
        my $level = $_;
        $level => sub {
            my $app = shift;
            $self->message( $level, sprintf(shift, @_) );
        };
    } @levels_to_register;

    # Register the log levels
    $self->register(%LEVELS);

    # Also register the the message method as 'logger'
    $self->register( logger => sub {
        shift;
        $self->message(@_);
    });
}

sub message {
    my ( $self, $level, $message ) = @_;
    my @a    = localtime(time);
    my $date = sprintf(
        "%4i-%02i-%02i %02i:%02i:%02i",
        $a[5] + 1900,
        $a[4] + 1,
        $a[3], $a[2], $a[1], $a[0]
    );

    $self->{logger}->log(
        level   => $level,
        message => sprintf( '%s - %s - %s', $date, $level, $message )
    );
}

1;
