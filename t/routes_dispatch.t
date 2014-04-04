
use lib 't/lib';
use strict;
use warnings;

use Test::More;
use MyApp;
use HTTP::Request::Common;
use Kelp::Test;

# Init
my $app = MyApp->new;
my $r = $app->routes;
$r->rebless(1);
my $t = Kelp::Test->new( app => $app );

# Controller
$r->add( '/a' => 'Controller::blessed' );
$t->request( GET '/a' )
  ->content_is('MyApp::Controller');

# CODE
$r->add( '/b' => sub {1});
$t->request( GET '/b' )
  ->content_is(1);

# Attribute
$r->add( '/c' => 'Controller::attrib' );
$t->request( GET '/c' )
  ->content_is( $app->path );

done_testing;
