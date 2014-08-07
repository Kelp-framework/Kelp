package Kelp::Module::Config::Less;
use Kelp::Base 'Kelp::Module::Config';

# Kelp::Less applications start with no modules or middleware
attr data => sub {
    my $self = shift;
    my $hash = $self->SUPER::data();
    $hash->{modules} = $hash->{middleware} = [];
    return $hash;
};

1;

__END__

=pod

=head1 TITLE

Kelp::Module::Config::Less

=head1 DESCRIPTION

Light config for L<Kelp::Less>

=head1 SEE ALSO

L<Kelp>, L<Kelp::Less>

=cut
