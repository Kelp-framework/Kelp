package Kelp::Module::Config;
use Kelp::Base 'Kelp::Module';
use Carp;

# Extension to look for
attr ext => 'pl';

# Directory where config files are
attr path => sub {
    my $self = shift;
    return $ENV{KELP_CONFIG_DIR} // ($self->app->path . '/conf');
};

attr separator => qr/\./;

# Defaults
attr data => sub {
    my $self = shift;

    # Encoding
    my $encoding = 'UTF-8';

    # Return a big hash with default values
    return {

        # Default charset is UTF-8
        charset => $encoding,

        app_url => 'http://localhost:5000',

        # Modules to load
        modules => [qw/JSON Template/],

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
};

sub get {
    my ( $self, $path ) = @_;
    return unless $path;
    my @a = split( $self->separator, $path );
    my $val = $self->data;
    for my $chunk (@a) {
        if ( ref($val) eq 'HASH' ) {
            $val = $val->{$chunk};
        }
        else {
            croak "Config path $path breaks at '$chunk'";
        }
    }
    return $val;
}

# Override this one to use other config formats.
sub load {
    my ( $self, $filename ) = @_;

    # Open and read file
    open( my $in, "<:encoding(UTF-8)", $filename )
      or do {
        warn "Can not read config file " . $filename;
        return {};
      };

    my $text = do { local $/ = undef; <$in> };
    close($in);

    my $_eval = sub {
        local $@;
        return (eval shift, $@);
    };

    my ( $hash, $error ) = $_eval->( $text );
    die "Config file $filename parse error: " . $error if $error;
    die "Config file $filename did not return a HASH - $hash"
      unless ref $hash eq 'HASH';

    return $hash;
}

sub build {
    my ( $self, %args ) = @_;

    # Look for the main and mode config files
    my $main_file = sprintf( '%s/config.%s', $self->path, $self->ext );
    my $mode_file =
      sprintf( '%s/%s.%s', $self->path, $self->app->mode, $self->ext );
    if ( !-e $mode_file ) {
        $mode_file = sprintf( '%s/config_%s.%s',
            $self->path, $self->app->mode, $self->ext );
    }

    my $hash = $self->data;

    # Merge the main config file
    if ( -r $main_file ) {
        $hash = _merge( $self->data, $self->load($main_file) );
    }

    # Merge the mode config file
    if ( -r $mode_file ) {
        $hash = _merge( $hash, $self->load($mode_file) );
    }

    # Register two methods: config and config_hash
    $self->register(
        config_hash => $self->data,
        config      => sub {
            my ( $app, $path ) = @_;
            return $self->get($path);
        }
    );
}

sub _merge {
    my ( $a, $b ) = @_;

    return $b
      if !ref($a)
      || !ref($b)
      || ref($a) ne ref($b)
      || ref($a) ne 'HASH';

    for my $k ( keys %$b ) {
        $a->{$k} =
          exists $a->{$k}
          ? _merge( $a->{$k}, $b->{$k} )
          : $b->{$k};
    }

    return $a;
}

1;

__END__

=pod

=head1 NAME

Kelp::Module::Config - Configuration for Kelp applications

=head1 DESCRIPTION

This is one of the two modules that are automatically loaded for each and every
Kelp application. It uses L<Config::Any::Perl> to read Perl-style hashes from files
and merge them depending on the value of the C<mode> attribute.

The main configuration file name is C<config.pl>, and it will be searched in the
C<conf> directory. You can also set the C<KELP_CONFIG_DIR> environmental
variable with the path to the configuration files.

This module brings a hash with default values, so if there are no configuration
files found, those values will be used.
If you create a configuration file C<conf/config.pl>, it will add to or override
the default values. If in addition to that there is a I<mode>.pl file, then it
will be merged to the config last.

=head1 REGISTERED METHODS

This module registers the following methods into the underlying app:

=head2 config

A wrapper for the C</get> method.

    # Somewhere in the app
    my $pos = $self->config('row.col.position');

    # Gets {row}->{col}->{position} from the config hash

=head2 config_hash

A reference to the entire configuration hash.

    my $pos = $self->config_hash->{row}->{col}->{position};

Using this or C<config> is entirely up to the application developer.

=head1 ATTRIBUTES

This module implements some attributes, which can be overridden by subclasses.

=head2 ext

The file extension of the configuration files. Default is C<pl>.

=head2 separator

A regular expression for the value separator used by L</get>. The default is
C<qr/\./>, i.e. a dot.

=head2 data

The hashref with data contained in all of the merged configurations.

=head1 METHODS

The module also implements some methods for parsing the config files, which can
be overridden in extending classes.

=head2 get

C<get($string)>

Get a value from the config using a separated string.

    my $value = $c->get('bar.foo.baz');
    my $same  = $c->get('bar')->{foo}->{baz};
    my $again = $c->data->{bar}->{foo}->{baz};

By default the separator is a dot, but this can be changed via the
L</separator> attribute.

=head2 load

C<load(filename)>

Loads, and parses the file C<$filename> and returns a hash reference.

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
C<['JSON', 'Template']>

=head2 modules_init

A hashref with initializations for each of the loaded modules, except this one,
ironically.

=head2 middleware

An arrayref with middleware to load on startup. The default value is an
empty array.

=head2 middleware_init

A hashref with initialization arguments for each of the loaded middleware.

=head1 SUBCLASSING

You can subclass this module and use other types of configuration files
(for example YAML). You need to override the C<ext> attribute
and the C<load> subroutine.

    package Kelp::Module::Config::Custom;
    use Kelp::Parent 'Kelp::Module::Config';

    # Set the config file extension to .cus
    attr ext => 'cus';

    sub load {
        my ( $self, $filename ) = @_;

        # Load $filename, parse it and return a hashref
    }

    1;

Later ...

    # app.psgi
    use MyApp;

    my $app = MyApp->new( config_module => 'Config::Custom' );

    run;

The above example module will look for C<config/*.cus> to load as configuration.

=cut
