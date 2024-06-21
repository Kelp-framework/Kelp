package Kelp::Module::Config::Null;
use Kelp::Base 'Kelp::Module::Config';

attr 'data' => sub { {} };

sub load { {} }

1;

# This config module has no defaults and won't load your configuration files.
# The configuration will be completely empty and can be only set by hand in
# code. It's very likely going to make some parts of the system not function as
# they should unless you provide the same set of defaults as
# Kelp::Module::Config::Less (and keep it updated)

