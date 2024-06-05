# Options specific to development only
{
    # Add StackTrace in development
    '+middleware'   => ['StackTrace'],
    middleware_init => {
        StackTrace => {
            force => 1,
        },
    },

    modules_init => {
        # One log for errors and one for debug
        Logger => {
            '+outputs' => [
                [
                    'Screen',
                    name      => 'debug',
                    min_level => 'debug',
                    max_level => 'notice',
                    stderr => 0,
                    newline => 1,
                    utf8 => 1,
                ],
            ],
        },
    },
};

