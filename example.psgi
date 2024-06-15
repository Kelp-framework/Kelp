use v5.40;
use Kelp::Less;

module 'JSON';

get '/?who' => sub ($self, $who //= 'world') {
	return {
		success => true,
		message => "Hello, $who!",
	};
};

run;

# run with: plackup example.psgi

