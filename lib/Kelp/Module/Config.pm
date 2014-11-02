package Kelp::Module::Config;
use Kelp::Base 'Kelp::Module';
use Carp;
use Try::Tiny;
use Test::Deep;

# Extension to look for
attr ext => 'pl';

# Directory where config files are
attr path => sub {
    my $self = shift;
    return [
        $ENV{KELP_CONFIG_DIR},
        'conf',
        $self->app->path,
        $self->app->path . '/conf',
        $self->app->path . '/../conf'
    ]
};

attr separator => sub { qr/\./ };

# Defaults
attr data => sub {
    my $self = shift;

    # Return a big hash with default values
    return {

        # Default charset is UTF-8
        charset => 'UTF-8',

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
                paths => [
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

    my ( $hash, $error );
    {
        local $@;
        my $app = $self->app;
        my $module = $filename;
        $module =~ s/\W/_/g;
        $hash =
            eval "package Kelp::Module::Config::Sandbox::$module;"
          . "use Kelp::Base -strict;"
          . "sub app; local *app = sub { \$app };"
          . "sub include(\$); local *include = sub { \$self->load(\@_) };"
          . $text;
        $error = $@;
    }

    die "Config file $filename parse error: " . $error if $error;
    die "Config file $filename did not return a HASH - $hash"
      unless ref $hash eq 'HASH';

    return $hash;
}

sub build {
    my ( $self, %args ) = @_;

    # Get an easy access reference to the data
    my $data_ref = $self->data;

    # Create a private sub that searches for a file in all the paths
    # specified in $self->path
    my $find = sub {
        my $name = shift;
        my @paths = ref( $self->path ) ? @{ $self->path } : ( $self->path );
        for my $path (@paths) {
            next unless defined $path;
            my $filename = sprintf( '%s/%s.%s', $path, $name, $self->ext );
            return $filename if -r $filename;
        }
    };

    # Create a private sub that parses a config file
    my $process = sub {
        my $name   = shift;
        my $parsed = {};
        try {
            $parsed = $self->load($name);
        }
        catch {
            die "Parsing $name died with error: '${_}'";
        };
        $data_ref = _merge( $data_ref, $parsed );
    };

    # Find, parse and merge 'config' and mode files
    for my $name ( 'config', $self->app->mode ) {
        if ( my $filename = $find->($name) ) {
            $process->($filename);
        }
        else {
            if ( $ENV{KELP_CONFIG_WARN} ) {
                my $message =
                  $name eq 'config'
                  ? "Main config file not found or not readable"
                  : "Config file for mode '$name' not found or not readable";
                  warn $message;
            }
        }
    }

    # Undocumented! Add 'extra' argument to unlock these special features:
    # 1. If the extra argument contains a HASH, it will be merged to the
    #    configuration upon loading.
    # 2. A new attribute '_cfg' will be registered into the app, which has
    # three methods: merge, clear and set. Use them to merge a hash into
    # the configuration, clear it, or set it to a new value. You can do those
    # at any point in the life of the app.
    #
    if ( my $extra = delete $args{extra} ) {
        $self->data( _merge( $self->data, $extra ) ) if ref($extra) eq 'HASH';
        $self->register(

         # A tiny object containing only merge, clear and set. Very useful when
         # you're writing tests and need to add new config options, set the
         # entire config hash to a new value, or clear it completely.
            _cfg => Plack::Util::inline_object(
                merge => sub {
                    $self->data( _merge( $self->data, $_[0] ) );
                },
                clear => sub { $self->data( {} ) },
                set   => sub { $self->data( $_[0] ) }
            )
        );
    }

    $self->register(

        # Return the entire config hash
        config_hash => $self->data,

        # A wrapper arount the get method
        config => sub {
            my ( $app, $path ) = @_;
            return $self->get($path);
        }
    );
}

sub _merge {
    my ( $a, $b, $sigil ) = @_;

    return $b
      if !ref($a)
      || !ref($b)
      || ref($a) ne ref($b);

    if ( ref $a eq 'ARRAY' ) {
        return $b unless $sigil;
        if ( $sigil eq '+' ) {
            for my $e (@$b) {
                push @$a, $e unless grep { eq_deeply( $_, $e ) } @$a;
            }
        }
        else {
            $a = [
                grep {
                    my $e = $_;
                    !grep { eq_deeply( $_, $e ) } @$b
                } @$a
            ];
        }
        return $a;
    }
    elsif ( ref $a eq 'HASH' ) {
        for my $k ( keys %$b ) {

            # If the key is an array then look for a merge sigil
            my $s = ref($b->{$k}) eq 'ARRAY' && $k =~ s/^(\+|\-)// ? $1 : '';

            $a->{$k} =
              exists $a->{$k}
              ? _merge( $a->{$k}, $b->{"$s$k"}, $s )
              : $b->{$k};
        }

        return $a;
    }
    return $b;
}

1;

__END__

=pod

=head1 NAME

Kelp::Module::Config - Configuration for Kelp applications

=head1 DESCRIPTION

This is one of the two modules that are automatically loaded for each and every
Kelp application. The other one is L<Kelp::Module::Routes>. It reads
configuration files containing Perl-style hashes, and merges them depending on
the value of the application's C<mode> attribute.

The main configuration file name is C<config.pl>, and it will be searched in
the C<conf> and C<../conf> directories. You can also set the C<KELP_CONFIG_DIR>
environmental variable with the path to the configuration files.

This module comes with some L<default values|/DEFAULTS>, so if there are no
configuration files found, those values will be used.  Any values from
configuration files will add to or override the default values.

=head1 ORDER

First the module will look for C<conf/config.pl>, then for
C<../conf/config.pl>.  If found, they will be parsed and merged into the
default values.  The same order applies to the I<mode> file too, so if the
application L<mode|Kelp/mode> is I<development>, then C<conf/development.pl>
and C<../conf/development.pl> will be looked for. If found, they will also be
merged to the config hash.

=head1 ACCESSING THE APPLICATION

The application instance can be accessed within the config files via the C<app>
keyword.

    {
        bin_path => app->path . '/bin'
    }

=head1 INCLUDING FILES

To include other config files, one may use the C<include> keyword.

    # config.pl
    {
        modules_init => {
            Template => include('conf/my_template.pl')
        }
    }

    # my_template.pl
    {
        path => 'views/',
        utf8 => 1
    }

Any config file may be included as long as it returns a hashref.

=head1 MERGING

The first configuration file this module will look for is C<config.pl>. This is
where you should keep configuration options that apply to all running
environments.  The mode-specific configuration file will be merged to this
config, and it will take priority. Merging is done as follows:

=over

=item Scalars will always be overwritten.

=item Hashes will be merged.

=item Arrays will be overwritten, except in case when the name of the array contains a
sigil as follows:

=over

=item

C<+> in front of the name will add the elements to the array:

    # in config.pl
    {
        middleware => [qw/Bar Foo/]
    }

    # in development.pl
    {
        '+middleware' => ['Baz']    # Add 'Baz' in development
    }

=cut

=item

C<-> in front of the name will remove the elements from the array:

    # in config.pl
    {
        modules => [qw/Template JSON Logger/]
    }

    # in test.pl
    {
        '-modules' => [qw/Logger/]  # Remove the Logger modules in test mode
    }

=cut

=item

No sigil will cause the array to be completely replaced:

    # in config.pl
    {
        middleware => [qw/Bar Foo/]
    }

    # in cli.pl
    {
        middleware => []    # No middleware in CLI
    }

=cut

=back

Note that the merge sigils only apply to arrays. All other types will keep the
sigil in the key name:

    # config.pl
    {
        modules      => ["+MyApp::Fully::Qualified::Name"],
        modules_init => {
            "+MyApp::Fully::Qualified::Name" => { opt1 => 1, opt2 => 2 }
        }
    }

    # development.pl
    {
        modules_init => {
            "+MyApp::Fully::Qualified::Name" => { opt3 => 3 }
        }
    }

=back

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

=head3 _cfg

A tiny object that contains only three methods - B<merge>, B<clear> and B<set>.
It allows you to merge values to the config hash, clear it completely or
set it to an entirely new value. This method comes handy when writing tests.

    # Somewhere in a .t file
    my $app = MyApp->new( mode => 'test' );

    my %original_config = %{ $app->config_hash };
    $app->_cfg->merge( { middleware => ['Foo'] } );

    # Now you can test with middleware Foo added to the config

    # Revert to the original configuration
    $app->_cfg->set( \%original_config );

=head1 ATTRIBUTES

This module implements some attributes, which can be overridden by subclasses.

=head2 ext

The file extension of the configuration files. Default is C<pl>.

=head2 separator

A regular expression for the value separator used by L</get>. The default is
C<qr/\./>, i.e. a dot.

=head2 path

Specifies a path, or an array of paths where to look for configuration files.
This is particularly useful when writing tests, because you can set a custom
path to a peculiar configuration.

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

An arrayref with module names to load on startup. The default value is
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

=head1 TESTING

Since the config files are searched in both C<conf/> and C<../conf/>, you can
use the same configuration set of files for your application and for your tests.
Assuming the all of your test will reside in C<t/>, they should be able to load
and find the config files at C<../conf/>.

=head1 ENVIRONMENT VARIABLES

=head2 KELP_CONFIG_WARN

This module will not warn for missing config and mode files. It will
silently load the default configuration hash. Set KELP_CONFIG_WARN to a
true value to make this module warn about missing files.

    $ KELP_CONFIG_WARN=1 plackup app.psgi

=cut
