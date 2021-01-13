# Options specific to deployment only
{
    modules_init => {

        # In deployment, only log the errors
        Logger => {
            outputs => [
                [
                    'File',
                    name      => 'error',
                    filename  => 'log/error.log',
                    min_level => 'error',
                    mode      => '>>',
                    newline   => 1,
                    binmode   => ":encoding(UTF-8)"
                ],
            ]
        },

        # Compress JSON output in deployment
        JSON => {
            pretty => 0
        },
    }
};
