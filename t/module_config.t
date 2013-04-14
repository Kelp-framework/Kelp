
# Allow the redefining of globs at Kelp::Module
BEGIN {
    $ENV{KELP_REDEFINE} = 1;
}

use Kelp::Base -strict;
use Kelp::Module::Config;
use Plack::Util;
use FindBin '$Bin';
use Test::More;
use Test::Exception;

# Basic
my $app = Plack::Util::inline_object(
    mode => sub { "test" }
);
my $c = Kelp::Module::Config->new( app => $app );
isa_ok $c, 'Kelp::Module::Config';

# No file
$c->data({ C => 'baz' });
$c->path("$Bin/conf/missing");
$c->build();
is_deeply( $c->data, { C => 'baz' } );

# Single file
$c->data({ C => 'baz' });
$c->path("$Bin/conf/a");
$c->build();
is_deeply( $c->data, { A => 'bar', B => 'foo', C => 'baz' } );

# Main + Mode file
$c->data({ C => 'baz' });
$c->path("$Bin/conf/b");
$c->build();
is_deeply( $c->data, { A => 'bar', B => 'new', C => 'baz' } );

# Mode file only
$c->data({ C => 'baz' });
$c->path("$Bin/conf/c");
$c->build();
is_deeply( $c->data, { B => 'new', C => 'baz' } );

# Syntax error
$c->data({ C => 'baz' });
$c->path("$Bin/conf/e");
dies_ok { $c->build() };

# Does not return a hash
$c->data({ C => 'baz' });
$c->path("$Bin/conf/f");
dies_ok { $c->build() };

done_testing;
