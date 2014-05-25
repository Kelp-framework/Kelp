package MyApp2::Controller;
use Kelp::Base 'MyApp2';

sub blessed { ref shift }

# Access to modules
sub test_module { shift->config('charset') }

1;
