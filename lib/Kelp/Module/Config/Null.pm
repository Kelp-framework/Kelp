package Kelp::Module::Config::Null;
use Kelp::Base 'Kelp::Module::Config';

attr 'data' => sub { {} };

sub load { {} }

1;

__END__

=pod

=head1 NAME

Kelp::Module::Config::None - Completely empty configuration

=head1 DESCRIPTION

It has no defaults and won't load your configuration files. The configuration
will be completely empty and can be only set by hand in code.

=head1 SEE ALSO

L<Kelp::Module::Config>

=cut

