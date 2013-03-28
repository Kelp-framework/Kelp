package Kelp::Module::Config;

use Kelp::Base 'Kelp::Module';
use Config::Hash;

sub build {
    my ( $self, %args ) = @_;

    # Add a reference to the app in the config param hash
    $args{param}->{app} = $self->app;

    # Create the config object with some default attributes,
    # but have %args at the end to trump all.
    my $filename = $self->app->path . '/' . lc( $self->app->name ) . '.conf';
    my $config = Config::Hash->new(
        data => $self->defaults,
        mode => $self->app->mode,
        ( -e $filename ? ( filename => $filename ) : () ),
        %args
    );

    # Register two methods: config and config_hash
    $self->register(
        config_hash => $config->data,
        config => sub {
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

        # Module initialization params
        modules => {

            # Template
            Template => {
                INCLUDE_PATH => $self->app->path . '/views'
            },

            # Routes
            Routes => {
                base => ref( $self->app )
            },

            # Logger - Default config is for developement
            Logger => {
                outputs => [
                    [
                        'File',
                        name      => 'debug',
                        filename  => 'log/debug.log',
                        min_level => 'debug',
                        mode      => '>>',
                        newline   => 1,
                        binmode   => ":encoding($encoding)"
                    ], [
                        'File',
                        name      => 'error',
                        filename  => 'log/error.log',
                        min_level => 'error',
                        mode      => '>>',
                        newline   => 1,
                        binmode   => ":encoding($encoding)"
                    ],
                ]
            },

            # JSON
            JSON => {},
          },

    };

    return $result;
}

1;
