# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;

# https://github.com/Dridi/libvmod-querystring
import querystring;

# Default backend definition. Set this to point to your content server.
backend www {
  .host = "nginx";
  .port = "80";
  .max_connections = 256;
}

# Define an access control list to restrict cache purging.
acl purge {
  "nginx";
}

sub vcl_hit {
  if (obj.ttl >= 0s) {
    # A pure unadulterated hit, deliver it
    return (deliver);
  }
  if (obj.ttl + obj.grace > 0s) {
    # Object is in grace, deliver it
    # Automatically triggers a background fetch
    return (deliver);
  }
  # fetch & deliver once we get the result
  return (fetch);
}

sub vcl_recv {
  # If this is a cache purge request, make sure the request is coming from a trusted actor.
  if (req.method == "PURGE") {
    if (!client.ip ~ purge) {
      return(synth(405, "Not allowed."));
    }
    return (purge);
  }

  if (req.method != "GET" &&
      req.method != "HEAD" &&
      req.method != "PUT" &&
      req.method != "POST" &&
      req.method != "TRACE" &&
      req.method != "OPTIONS" &&
      req.method != "PATCH" &&
      req.method != "DELETE") {
    return (pipe);
  }

  if (req.http.Upgrade ~ "(?i)websocket") {
    return (pipe);
  }

  if (req.method != "GET" && req.method != "HEAD") {
    return (pass);
  }

  if (req.http.Authorization) {
    return (pass);
  }

  # Bypass cache for WordPress admin page requests.
  if (req.url~ "^/wp-admin/") {
    return (pass);
  }

  # At this point, we're assuming we can't just pass or pipe the request and
  # need to start thinking about how it might be cached.

  if (req.url ~ "\#") {
    set req.url = regsub(req.url, "\#.*$", "");
  }

  # For static file access, strip all querystring parameters.
  if (req.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpe?g|js|less|mp[34]|otf|pdf|png|rar|rtf|swf|tar|tgz|ttf|txt|wav|webm|woff|xml|zip)(\?.*)?$") {
    unset req.http.Cookie;
    set req.url = querystring.remove(req.url);
    return (hash);
  }

  # Whitelist query string parameters for WordPress.
  set req.url = querystring.filter_except(req.url,
                                            "sort" + querystring.filtersep() +
                                            "q" + querystring.filtersep() +
                                            "dom" + querystring.filtersep() +
                                            "dedupe_hl" + querystring.filtersep() +
                                            "filter" + querystring.filtersep() +
                                            "attachment" + querystring.filtersep() +
                                            "attachment_id" + querystring.filtersep() +
                                            "author" + querystring.filtersep() +
                                            "author_name" + querystring.filtersep() +
                                            "cat" + querystring.filtersep() +
                                            "calendar" + querystring.filtersep() +
                                            "category_name" + querystring.filtersep() +
                                            "comments_popup" + querystring.filtersep() +
                                            "cpage" + querystring.filtersep() +
                                            "day" + querystring.filtersep() +
                                            "dedupe_hl" + querystring.filtersep() +
                                            "dom" + querystring.filtersep() +
                                            "error" + querystring.filtersep() +
                                            "exact" + querystring.filtersep() +
                                            "exclude" + querystring.filtersep() +
                                            "feed" + querystring.filtersep() +
                                            "hour" + querystring.filtersep() +
                                            "m" + querystring.filtersep() +
                                            "minute" + querystring.filtersep() +
                                            "monthnum" + querystring.filtersep() +
                                            "more" + querystring.filtersep() +
                                            "name" + querystring.filtersep() +
                                            "order" + querystring.filtersep() +
                                            "orderby" + querystring.filtersep() +
                                            "p" + querystring.filtersep() +
                                            "page_id" + querystring.filtersep() +
                                            "page" + querystring.filtersep() +
                                            "paged" + querystring.filtersep() +
                                            "pagename" + querystring.filtersep() +
                                            "pb" + querystring.filtersep() +
                                            "post_type" + querystring.filtersep() +
                                            "posts" + querystring.filtersep() +
                                            "preview" + querystring.filtersep() +
                                            "q" + querystring.filtersep() +
                                            "robots" + querystring.filtersep() +
                                            "s" + querystring.filtersep() +
                                            "search" + querystring.filtersep() +
                                            "second" + querystring.filtersep() +
                                            "sentence" + querystring.filtersep() +
                                            "sort" + querystring.filtersep() +
                                            "static" + querystring.filtersep() +
                                            "subpost" + querystring.filtersep() +
                                            "subpost_id" + querystring.filtersep() +
                                            "taxonomy" + querystring.filtersep() +
                                            "tag" + querystring.filtersep() +
                                            "tb" + querystring.filtersep() +
                                            "tag_id" + querystring.filtersep() +
                                            "term" + querystring.filtersep() +
                                            "tb" + querystring.filtersep() +
                                            "url" + querystring.filtersep() +
                                            "w" + querystring.filtersep() +
                                            "withcomments" + querystring.filtersep() +
                                            "withoutcomments" + querystring.filtersep() +
                                            "year");

  # Sort the querystring parameters, so different orders of the same produce a single cache object.
  if (req.url ~ "\?") {
    set req.url = querystring.sort(req.url);
  }

  if (req.http.cookie) {
    if (req.url ~ "preview") {
      # Keep WordPress cookies for preview
      return (pass);
    } else {
      # drop all cookies.
      unset req.http.cookie;
    }
  }

  return (hash);
}

sub vcl_pipe {

  if (req.http.upgrade) {
    set bereq.http.upgrade = req.http.upgrade;
  }

  return (pipe);
}

sub vcl_backend_response {
  # If the back-end response is 500-level, don't bust the cached object.
  if (beresp.status == 500 || beresp.status == 502 || beresp.status == 503 || beresp.status == 504) {
    return (abandon);
  }
  # Don't allow the backend to set cookies for static file requests.
  if (bereq.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpe?g|js|less|mp[34]|otf|pdf|png|rar|rtf|swf|tar|tgz|ttf|txt|wav|webm|woff|xml|zip)(\?.*)?$") {
    unset beresp.http.set-cookie;
  }

  if (beresp.status == 301 || beresp.status == 302) {
    set beresp.http.location = regsub(beresp.http.location, ":[0-9]+", "");
  }

  # Don't cache on these kind of requests.
  if (beresp.ttl <= 0s || beresp.http.set-cookie || beresp.http.vary == "*") {
    set beresp.ttl = 120s;
    set beresp.uncacheable = true;
    return (deliver);
  }

  set beresp.grace = 6h;

  return (deliver);
}

sub vcl_deliver {

  unset resp.http.server;
  unset resp.http.via;
  unset resp.http.x-powered-by;
  unset resp.http.x-runtime;
  unset resp.http.x-varnish;

  return (deliver);
}