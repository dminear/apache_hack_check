# apache_hack_check

Perl module for Apache mod_perl to check frequent attack vectors

I noticed some common URL requests coming in for particular URLs. Rather than waste
time with processing these, I wanted to capture the IPs and then do some
analysis. It also helps Apache so it doesn't have to keep processing the same
bad requests and spend compute cycles to get to an error status. The request is
rejected at the beginning of the request cycle.

## Somewhere in your Apache configuration

```
PerlModule ModPerl::DanHandler
PerlAccessHandler ModPerl::DanHandler
```
