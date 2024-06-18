package StringifyingException;
use Kelp::Base;

attr data => undef;

use overload q{""} => sub {
    return 'Exception with data: [' . (join ',', @{$_[0]->data}) . ']';
};

1;

