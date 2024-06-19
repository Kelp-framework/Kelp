{
    modules_init => {
        Template => {
            paths => [] # No error templates
        }
    },
    middleware      => ['StackTrace'],
    middleware_init => {
        StackTrace => {
            force => 1,
            no_print_errors => 1,
        }
    }
};

