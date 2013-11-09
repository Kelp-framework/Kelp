{
    middleware      => ['XFramework', 'ContentLength'],
    middleware_init => {
        XFramework => {
            framework => 'Changed'
        }
    }
};
