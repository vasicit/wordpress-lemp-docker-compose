vcl 4.1;

backend default {
       .host = nginx;
       .port = "80";
}

#unsetting wordpress cookies

sub vcl_rec{
  ..

  set req.http.cookie = regsuball(req.http.cookie, "wp-settings-\d+=[^;]+(; )?", "");

  set req.http.cookie = regsuball(req.http.cookie, "wp-settings-time-\d+=[^;]+(; )?", "");

  set req.http.cookie = regsuball(req.http.cookie, "wordpress_test_cookie=[^;]+(; )?", "");

  if (req.http.cookie == "") {

  unset req.http.cookie;
  }
}

# exclude wordpress url

if (req.url ~ "wp-admin|wp-login") {

return (pass);

}

# extending caching time

sub vcl_backend_response {

  if (beresp.ttl == 120s) {

    set beresp.ttl = 1h;

  }
}

acl internal {
  nginx;
}
# Allowing which address can access cron.php or install.php,
# add the following in acl.

#handling purge requsets

sub vcl_recv{
  ...
  if (req.method == "PURGE") {

    if (req.http.X-Purge-Method == "regex") {

      ban("req.url ~ " + req.url + " &amp;&amp; req.http.host ~ " + req.http.host);

    return (synth(200, "Banned."));

  } else {

    return (purge);

  }
  }
}

acl purge {
  nginx;
}

...

if (req.method == "PURGE") {

  if (client.ip !~ purge) {
    return (synth(405));

}