# Common settings
{
    modules      => [qw/Template JSON Logger/],
    modules_init => {

        # One log for errors and one for debug
        Logger => {
            outputs => [
                [
                    'File',
                    name      => 'error',
                    filename  => 'log/error.log',
                    min_level => 'warn',
                    mode      => '>>',
                    newline   => 1,
                    binmode   => ':encoding(UTF-8)',
                ],
            ],
        },

        JSON => {
            pretty => 1,
            utf8 => 0, # will not encode wide characters
        },
    },
};

