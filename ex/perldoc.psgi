use Kelp::Less;
use IPC::Open3;
use Symbol 'gensym';

module 'Logger::Simple';

get '/:perldoc_page' => sub {
	my ($self, $name) = @_;

	# safely call perldoc to render page in html
	my $pid = open3(undef, my $output, my $error = gensym, 'perldoc', '-T', '-o', 'html', $name);

	# read the output, then reap the process
	my $contents = do {
		local $/;
		readline $output;
	};
	my $errors = do {
		local $/;
		readline $error;
	};
	waitpid $pid, 0;

	# if we did not succeed, assume there's no such docs page
	my $status = $? >> 8;
	$self->res->render_error(404, $errors)
		if $status != 0;

	# return the contents - if the response was not rendered, it will be
	# used as page content (html)
	return $contents;
};

run;

