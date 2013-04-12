package Kelp::Module::Config;

use Kelp::Base 'Kelp::Module';
use Config::Hash;

sub build {
    my ( $self, %args ) = @_;

    # Add a reference to the app in the config param hash
    $args{param}->{app} = $self->app;

    # Look for the config file
    my $filename = 'conf/config.pl';
    for ("", "/..") {
        my $path = $self->app->path . "${_}/conf";
        if ( -r "$path/config.pl" ) {
            $filename = "$path/config.pl";
            last;
        }
    }

    # Create the config object with some default attributes,
    # but have %args at the end to trump all.
    my $config   = Config::Hash->new(
        data     => $self->defaults,
        mode     => $self->app->mode,
        filename => $filename,
        %args
    );

    # Register two methods: config and config_hash
    $self->register(
        config_hash => $config->data,
        config      => sub {
            my ( $app, $path ) = @_;
            return $config->get($path);
        }
    );
}

sub defaults {
    my $self = shift;

    my $encoding = 'UTF-8';

    # Return a big hash with default values
    my $result = {

        # Default charset set to UTF-8
        charset => $encoding,

        app_url => 'http://localhost:5000',

        # Modules to load
        modules => [qw/JSON Template Logger/],

        # Module initialization params
        modules_init => {

            # Routes
            Routes => {
                base => ref( $self->app )
            },

            # Template
            Template => {
                INCLUDE_PATH => [
                    $self->app->path . '/views',
                    $self->app->path . '/../views'
                ]
            },

            # Logger - Default config is for development
            Logger => {
                outputs => [
                    [
                        'File',
                        name      => 'debug',
                        filename  => $self->app->path . '/log/debug.log',
                        min_level => 'debug',
                        mode      => '>>',
                        newline   => 1,
                        binmode   => ":encoding($encoding)"
                    ], [
                        'File',
                        name      => 'error',
                        filename  => $self->app->path . '/log/error.log',
                        min_level => 'error',
                        mode      => '>>',
                        newline   => 1,
                        binmode   => ":encoding($encoding)"
                    ],
                ]
            },

            # JSON
            JSON => {
                allow_blessed   => 1,
                convert_blessed => 1,
                utf8            => 1
            },
        },

        # List of the middleware to add
        middleware => [],

        # Initializations of the middleware
        middleware_init => {},

    };

    return $result;
}

1;

__END__

=pod

=head1 NAME

Kelp::Module::Config - Configuration for Kelp applications

=head1 DESCRIPTION

This is one of the two modules that are automatically loaded for each and every
Kelp application. It uses L<Config::Hash> to read Perl-style hashes from files
and merge them depending on the value of the C<mode> attribute.

The main configuration file name is C<config.pl>, and it will be searched in the
C<conf> directory or C<../conf>. The latter is convenient for running tests
which use the same configuration settings as the main app.

=head1 REGISTERED METHODS

This module registers the following methods into the underlying app:

=head2 config

A wrapper for the C<get> method in L<Config::Hash>.

    # Somewhere in the app
    my $pos = $self->config('row.col.position');

    # Gets {row}->{col}->{position} from the config hash

=head2 config_hash

A reference to the entire configuration hash.

    my $pos = $self->config_hash->{row}->{col}->{position};

Using this or C<config> is entirely up to the application developer.

=head1 DEFAULTS

This module sets certain default values. All of them may be overridden in any of
the C<conf/> files. It probably pays to view the code of this module and look
and the C<defaults> sub to see what is being set by default, but here is the
short version:

=head2 charset

C<UTF-8>

=head2 app_url

C<http://localhost:5000>

=head2 modules

An arrayrf with module names to load on startup. The default value is
C<['JSON', 'Template', 'Logger']>

=head2 modules_init

A hashref with initializations for each of the loaded modules, except this one,
ironically.

=head2 middleware

An arrayref with middleware to load on startup. The default value is an
empty array.

=head2 middleware_init

A hashref with iitialization arguments for each of the loaded middleware.

=cut
