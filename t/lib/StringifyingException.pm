package StringifyingException;
use Kelp::Base;

attr data => undef;

use overload
    q{""} => 'stringify',
    fallback => 1,
;

sub stringify {
    return 'Exception with data: [' . (join ',', @{$_[0]->data}) . ']';
}

1;

