package Kelp::Module::Config::Less;
use Kelp::Base 'Kelp::Module::Config';

# Kelp::Less applications start with no modules or middleware, but it surely
# can be used for normal applications as well.
attr data => sub {
    my $self = shift;
    my $hash = $self->SUPER::data();

    $hash->{modules} = [];
    $hash->{middleware} = [];

    return $hash;
};

1;

__END__

=pod

=head1 NAME

Kelp::Module::Config::Less - Configuration with less defaults

=head1 DESCRIPTION

Light config with no modules or middleware by default. Good if you want less
defaults and used by L<Kelp::Less>.

=head1 SEE ALSO

L<Kelp::Module::Config>

L<Kelp::Module::Config::Least>

=cut

