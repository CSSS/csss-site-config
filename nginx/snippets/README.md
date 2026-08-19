# Nginx snippets

This directory contains the snippets you can use throughout other configs.
Be careful modifying them as they may be used in multiple areas.

To use them add `include snippets/<snippet.conf>` in the server block.
```nginx
server {
    server_name example.com;

    include snippets/snippet.conf;
    # ...the rest of the config
}
```

You'll also need to move the snippets to `/etc/nginx/snippets`.

## Auth Guard (auth-guard.conf)

Adds two internal locations related to authentication.

- `/_auth`: Performs an internal authentication subrequest. It must return 2XX for Nginx to allow the original request to pass.
- `@login`: Redirects the user to our authentication flow.

### Usage

You'll include this snippet and also some other lines, based on if the site is a static site or a SPA.
You also need to include the `$auth_required_role` value to designate the protection level on those pages.
See csss-site-backend for available values.

```nginx
# Static site
server {
    server_name static.site;

    set $auth_required_role "exec";
    include snippets/auth-guard.conf;

    # ...

    location /path/to/protect {
        auth_request /_auth;
        error_page 401 = @login;

        try_files $uri $uri/ =404;
    }
}

# SPA
server {
    server_name spa.site;

    set $auth_required_role "exec";
    include snippets/auth-guard.conf;

    # ...

    # For convenience, SPAs can also use the blocks below.
    # This allows them to makes calls to `/auth/user` instead of `spa.site/auth/user`.
    # This works for `/auth/logout` as well.
    location = /auth/user {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_pass http://backend;
    }

    location = /auth/logout {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_pass http://backend;
    }

    # ...

    location /path/to/protect {
        auth_request /_auth;
        error_page 401 = @login;

        try_files $uri $uri/ /index.html =404;
    }
}
```
