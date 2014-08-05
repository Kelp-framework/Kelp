package Kelp::Module::Logger::StdErr;
use Kelp::Base 'Kelp::Module::Logger';
use Plack::Util;

sub _logger {
    my ( $self, %args ) = @_;
    Plack::Util::inline_object(
        log => sub {
            my (%args) = @_;
            say STDERR $args{message} // '';
        }
    );
}

1;
