#!/usr/bin/perl -w

use strict;
use CGI;
use POSIX;
use Redis::Client;

my $q = new CGI;                        # create new CGI object
my $daynum = POSIX::strftime("%j", gmtime time);
my $redis = Redis::Client->new( 'localhost', 6379 );
$redis->auth( $ENV{REDIS_PW} );
$redis->select(10);

print $q->header,                    # create the HTTP header
	$q->start_html( -title=>"Network Operations for JDAY $daynum",
									-script => [ 
											{ -type=>"text/javascript",
												-src => 'jquery-1.7.1.js' },
											{ -type=>"text/javascript",
												-src => 'dan.js' }
															]
								), # start the HTML
	$q->h3("Network Operations JDAY ",
			$q->a({href=>"http://landweb.nascom.nasa.gov/browse/calendar.html"}, "$daynum"),
			" - past 24 hours"),         # level 1 header
	$q->div( {-id=>"pic" }, $q->img( {-class=>"request", -src=>""} ),
				$q->img( {-class=>"io", -src=>""}),
				$q->img( {-class=>"aududu", -src=>""})
		);




	#$q->a( {-href=>""}, 'Link' ),
	#my $badips = `ls -1 /var/www/bad_ips/ | wc -l`;
	my $badips = $redis->keys( 'badip.*' );
	if (! $badips) { $badips = "no"; }
	print $q->p( "There are ", $q->a({href=>"/nop/lookup_badips.pl"}, "$badips"),
			" bad IP addresses." ),
	$q->end_html;                  # end the HTML

