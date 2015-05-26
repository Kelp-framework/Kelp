use lib 't/lib';
use MyApp;
use Test::More;

ok my $app = MyApp->new( request_obj  => 'MyApp::Request',
                         reqspose_obj => 'MyApp::Response',
                       ), q{can build object};

isa_ok $app->build_request({}) , 'MyApp::Request' , q{custom request object};
isa_ok $app->build_response, 'MyApp::Response', q{custom response object};

done_testing;
