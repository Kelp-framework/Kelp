package Kelp::Module::Template;

use Kelp::Base 'Kelp::Module';
use Template;
use Carp;

sub build {
    my ( $self, %args ) = @_;
    my $tt = Template->new( \%args ) || croak $Template::ERROR, "\n";

    # Register one method - template
    $self->register(
        template => sub {
            my ( $app, $template, $vars, @rest ) = @_;
            my $output;
            $tt->process( $template, $vars, \$output, binmode => ':utf8' )
              || croak $tt->error(), "\n";
            return $output;
        }
    );
}

1;
