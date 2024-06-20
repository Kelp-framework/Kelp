package Kelp::Module::Config::Least;
use Kelp::Base 'Kelp::Module::Config';

attr 'data' => sub { {} };

1;

__END__

=pod

=head1 NAME

Kelp::Module::Config::Least - Configuration with no defaults

=head1 DESCRIPTION

Empty default config, but still loads all your configuration files normally.

=head1 SEE ALSO

L<Kelp::Module::Config>

L<Kelp::Module::Config::Less>

=cut

