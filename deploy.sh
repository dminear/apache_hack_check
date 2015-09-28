#!/bin/bash
# copy the Apache handler to somewhere in the Perl library strucure
# probably need to 'sudo' this script if you are a regular user

cp DanHandler.pm /usr/local/lib/site_perl/ModPerl/DanHandler.pm
chown root:root  /usr/local/lib/site_perl/ModPerl/DanHandler.pm
chmod 644  /usr/local/lib/site_perl/ModPerl/DanHandler.pm
