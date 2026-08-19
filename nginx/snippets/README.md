# Nginx snippets

This directory contains the snippets you can use throughout other configs.
You can treat these snippets like they are copy-pasted line-by-line at the location they're included i.e. where you place them matters.
Be careful modifying them as they may be used in multiple Nginx config files.

To use snippets:
1. move the snippets you're using to `/etc/nginx/snippets` and
2. follow the snippet's documentation on how to use them.

## Auth Guard

The snippet is `auth-guard.conf` and it adds two internal locations related to authentication.

- `/_auth`: Performs an internal authentication subrequest. It must return 2XX for Nginx to allow the original request to pass.
- `@login`: Redirects the user to our authentication flow when referenced by an `error_page` directive.

### Usage

1. Add `auth-guard.conf` at the server level.
2. Place `error_page 401 = @login` at either server level or location blocks, depending on the site type.
3. Include the `$auth_required_role` value to designate the protection level on those pages. This is defined by your authentication server.

#### Static site

```nginx
server {
    server_name static.site;

    set $auth_required_role "exec";
    include snippets/auth-guard.conf;

    location /path/to/protect {
        auth_request /_auth;
        # You can also put the mapping at the server level so all locations inherit it.
        error_page 401 = @login;

        try_files $uri $uri/ =404;
    }
}
```

#### SPA

```nginx
server {
    server_name spa.site;

    set $auth_required_role "role";
    include snippets/auth-guard.conf;

    # ...

    # For convenience, SPAs can proxy these authentication endpoints through their own origin.
    # This allows them to make calls to `/auth/user` and `/auth/logout` without making cross-origin requests.
    # E.g. instead of `fetch('https://sfucsss.org/auth/user')`, your SPA can do `fetch('/auth/user')`
    # This avoids needing CORS for these authentication requests.
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

    location /path/to/protect {
        auth_request /_auth;
        error_page 401 = @login;

        try_files $uri $uri/ /index.html;
    }

}
```

## Shared Error Pages

Serves shared custom error pages based on errors handled by Nginx.
Errors returned by proxied upstreams can also use these, see [Proxied errors from upstream](#proxied-errors-from-upstream).

The snippets handle 403 Forbidden, 404 Not Found, 500 Internal Server Error, and 502 Bad Gateway.

**401 Unauthorized is not handled by these snippets**. See [Auth](#auth-guard) for how to handle that case.
There are two snippets to use this:

- `error-files.conf`: Holds the locations to the served pages and their assets.
- `errors.conf`: Holds the mappings to the error pages.

You can omit `error-files.conf` and serve your own `location` blocks, just follow how `error-files.conf` defines everything.

### Usage

1. Place error pages in `/var/www/html/errors/`. Any shared assets need to go into `/var/www/html/errors/assets/`.
2. Add `error-files.conf` at the server level.
3. Add `errors.conf` at either the server level _or_ in the location blocks where you want the custom error mappings to apply.

#### Static sites or SPAs without different error handling

If the site is completely static or is a SPA with no location block that will handle the mentioned statuses differently then apply both at the server level.

```nginx
server {
    server_name static.site;

    # ...no `/api` location block

    # The snippets can be applied at the server level.
    include snippets/error-files.conf;
    include snippets/errors.conf;

    location / {
        # ...
    }
}

```

#### SPAs that require different error handling

If the site is a SPA **and** has a location block, such as `/api`, whose error responses should not be served HTML files, then do the following:

- `error-files.conf`: Apply it at the server level.
- `errors.conf`: Apply it at the locations where you want error files to be served.

```nginx
server {
    server_name spa-with-api.site;

    # Always at the server level.
    include snippets/error-files.conf;

    location /api/ {
        # ...these could potentially send 403, 500, 502
    }

    location / {
        # In here so `/api/` doesn't inherit this.
        include snippets/errors.conf;

        #...
    }
}
```

##### Proxied errors from upstream

By default, Nginx passes error responses returned by a proxied upstream directly to a client, in other words error pages will not be served.
To allow `error_page` mappings to replace those responses you need to add `proxy_intercept_errors on;` for that location.

For example, say you have a web server and database and the request/response flow looks like this:

```
client <-> proxy (Nginx) <-> web server <-> database
```

The web server is up and the database is down so your web server returns 500 Internal Server Error. Nginx will not serve the 500 error page.
To have it serve the pages, tell Nginx to intercept those errors.

```nginx
server {
    server_name example.com;

    include snippets/error-files.conf;

    # Nginx will use the configured error pages
    # if `/app/...` returns one of the mapped errors.
    location /app/ {
        include snippets/errors.conf;

        proxy_pass http://app;

        # Nginx will serve the error pages.
        proxy_intercept_errors on;
    }

    # Upstream API errors are sent directly to the client
    # i.e. no error page is served.
    location /api/ {
        proxy_pass http://api;

        # Can be omitted since it's the default.
        proxy_intercept_errors off;
    }
}

```

### Error mapping inheritance

Nginx handles `error_page` inheritance in an all-or-nothing fashion.
Normally, an outer block's error page mappings are inherited by its nested blocks.
If a nested block defines its own error page mappings then none of the outer block mappings are inherited.

Example:

```nginx
# No inheritance
server {
    include snippets/error-files.conf;

    # Has mappings:
    #   error_page 403 /_errors/403.html;
    #   ...
    include snippets/errors.conf;

    location / {
        # The snippets mappings are not inherited.
        error_page 401 = @login;
    }
}

```

All desired mappings must be defined in the same block level.

```nginx
# Fixed version
server {
    include snippets/error-files.conf;

    location / {
        error_page 401 = @login;
        include snippets/errors.conf;
    }
}

```
