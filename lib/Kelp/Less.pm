package Kelp::Less;

use Kelp;
use Kelp::Base -strict;

our @EXPORT = qw/
  app
  attr
  route
  get
  post
  put
  del
  run
  param
  stash
  named
  req
  res
  template
  /;

our $app;

sub import {
    my $class  = shift;
    my $caller = caller;
    no strict 'refs';
    for my $sub (@EXPORT) {
        *{"${caller}::$sub"} = eval("\\\&$sub");
    }

    strict->import;
    warnings->import;
    feature->import(':5.10');

    $app = Kelp->new(@_);
    $app->routes->base('main');
}

sub route {
    my ( $path, $to ) = @_;
    $app->add_route( $path, $to );
}

sub get {
    my ( $path, $to ) = @_;
    route ref($path) ? $path : [ GET => $path ], $to;
}

sub post {
    my ( $path, $to ) = @_;
    route ref($path) ? $path : [ POST => $path ], $to;
}

sub put {
    my ( $path, $to ) = @_;
    route ref($path) ? $path : [ PUT => $path ], $to;
}

sub del {
    my ( $path, $to ) = @_;
    route ref($path) ? $path : [ DELETE => $path ], $to;
}

sub run {
    my @caller = caller;
    if ( $caller[0] =~ /Plack::Sandbox/ ) {
        return $app;
    }
    $app->run;
}

sub app      { $app }
sub attr     { Kelp::Base::attr( ref($app), @_ ) }
sub param    { $app->param(@_) }
sub stash    { $app->stash(@_) }
sub named    { $app->named(@_) }
sub req      { $app->req }
sub res      { $app->res }
sub template { $app->res->template(@_) }
sub debug    { $app->debug(@_) }
sub error    { $app->error(@_) }

1;

__END__

=pod

=head1 NAME

Kelp::Less - Quick prototyping with Kelp

=head1 DESCRIPTION

Please refer to the manual at L<Kelp::Manual::Less>

=cut
