requires 'Plack' => '0';
requires 'Log::Dispatch' => '0';
requires 'JSON::MaybeXS' => '0';
requires 'Path::Tiny' => '0';
requires 'Template::Tiny' => 0;
requires 'Try::Tiny' => 0;
requires 'Class::Inspector' => '0';
requires 'HTTP::Cookies' => '0';

on 'test' => sub {
	requires 'Test::Deep' => '0';
	requires 'Test::Exception' => '0';
	requires 'HTTP::Request' => '0';
};
