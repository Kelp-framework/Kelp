package Kelp::Module::Logger;

use Kelp::Base 'Kelp::Module';

use Carp;
use Log::Dispatch;
use Time::Piece;
use Data::Dumper;

attr logger => undef;
attr date_format => '%Y-%m-%d %T';
attr log_format => '%s - %s - %s';

sub _logger
{
    my ($self, %args) = @_;

    return Log::Dispatch->new(%args);
}

sub load_configuration
{
    my ($self, %args) = @_;

    for my $field (qw(date_format log_format)) {
        $self->$field(delete $args{$field})
            if $args{$field};
    }

    return %args;
}

sub build
{
    my ($self, %args) = @_;

    # load module config
    %args = $self->load_configuration(%args);

    # load logger with the rest of the config
    $self->logger($self->_logger(%args));

    # Build the registration hash
    my %LEVELS = map {
        my $level = $_;
        $level => sub {
            shift;
            $self->message($level, @_);
        };
    } qw(debug info error);

    # Register a few levels
    $self->register(%LEVELS);

    # Also register the message method as 'logger'
    $self->register(
        logger => sub {
            shift;
            $self->message(@_);
        }
    );
}

sub message
{
    my ($self, $level, @messages) = @_;
    my $date = localtime->strftime($self->date_format);

    local $Data::Dumper::Sortkeys = 1;
    for my $message (@messages) {
        $message = sprintf $self->log_format,
            $date,
            $level,
            (ref $message ? Dumper($message) : $message),
            ;

        $self->logger->log(level => $level, message => $message);
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
L<Log::Dispatch> as underlying logging module.

=head1 CONFIGURATION

All module's configuration is passed to L<Log::Dispatch>, so consult its docs
for details. In addition, following keys can be configured which change how the
module behaves:

=head2 date_format

A string in L<strftime
format|https://www.unix.com/man-page/FreeBSD/3/strftime/> which will be used to
generate the date.

By default, value C<'%Y-%m-%d %T'> is used.

=head2 log_format

A string in L<sprintf format|https://perldoc.perl.org/functions/sprintf> which
will be used to generate the log. Three string values will be used in this
string, in order: date, log level and the message itself.

By default, value C<'%s - %s - %s'> is used.

=head1 REGISTERED METHODS

=head2 debug

=head2 info

=head2 error

=head2 logger

C<< $app->logger(info => 'message') >> is equivalent to C<< $app->info('message') >>.

=head1 SEE ALSO

L<Kelp::Module::Logger::Simple> - always dumps to standard output

=cut

