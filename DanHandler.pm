package ModPerl::DanHandler;

use strict;
use warnings;
use FileHandle;
use IO::Socket::INET;
use Apache2::Log;
use Apache2::RequestRec ();
use Apache2::Connection ();
use APR::Table ();
use Redis;
use Apache2::Const -compile => qw(FORBIDDEN OK :log);

my $pw = $ENV{"REDIS_PW"};

my $redis = Redis->new(	host=>'localhost',
				port=>6379,
				password => $pw,
				reconnect=>60,
				every=>5000 );
$redis->select(10) if $redis;

# statsd socket
my $sock = IO::Socket::INET->new(	PeerPort => 8125,
					PeerAddr => '127.0.0.1',
					Proto => 'udp' );

sub handler {
	my $r = shift;
	
	my $str = $r->connection->client_ip();
	my $rlog = $r->log;

=comment
	# let these IPs through anytime
	if ( 
		$str =~ /192.168.0/  ||
		$str =~ /130.76/  ||
		$str =~ /47.151.7/ ||
		$str =~ /47.151.16/ ||
		#$str =~ /75.82/ ||
		#$str =~ /23.243.136/ ||
		#$str =~ /162.158.58/ ||
		#$str =~ /172.68.47/ ||
		0
		) {
		return Apache2::Const::OK;
	}
=cut

	# in case redis was not up when apache started, try to connect
	if (! defined $redis) {		# try to connect
		$redis = Redis->new(	host=>'localhost',
					port=>6379,
					password => $pw,
					reconnect=>60,
					every=>5000 );
		if ($redis) {
			$redis->auth($pw);
			$redis->select(10);
		}
	}
	
	# changed to not check the IP -- let the cloudflare caching work

=comment 
	# check the block list to get out as soon as possible if there
	if (defined $redis && $redis->get( 'badip.' . $str )) {
		$sock->send( "request.blocked:1|c\n" ) if defined $sock;
		#$rlog->notice("Bad IP ", $str, " blocked");
		return Apache2::Const::FORBIDDEN;
	}
=cut

	my $hostname = $r->hostname();
	my $src = $r->headers_in->get('X-Forwarded-For');
	#$rlog->notice("--X-Forwarded-For ", $src);
	#$rlog->notice("---hostname is ", $r->hostname() );
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	# current minute is in $min

=comment
	#let these hosts go through
	if ($hostname =~ /blog.aududu.com/ 
		|| $hostname =~ /scrappintwins.com/ 
		|| $hostname =~ /cindyminearphotography.com/ )
	 {
		$sock->send( "request.allowed:1|c\n" ) if defined $sock;
		my $name = $r->hostname();
		$name =~ tr/./-/;
		$sock->send( "request.hostname." . $name . ":1|c\n" ) if defined $sock;
		return Apache2::Const::OK;
	}
=cut

	# if there is an attempt to access "zencart/admin" or other attempts, 
	# then put the ip on the block list
	if ($r->unparsed_uri() =~ /zencart\/admin$/ ||
		$r->unparsed_uri() =~ /zencart\/+admin\/+/ ||
		$r->unparsed_uri() =~ /phpbb2/i  ||
		$r->unparsed_uri() =~ /wp-login/  ||
		$r->unparsed_uri() =~ /xmlrpc.php/  ||
		$r->unparsed_uri() =~ /INFORMATION_SCHEMA/  || 
		$r->unparsed_uri() =~ /CONCAT/  ||
		$r->unparsed_uri() =~ /phpMyAdmin/ ) {
		#$sock->send( "hacker.unparsed_uri." . $r->unparsed_uri() . ":1|c\n" ) if defined $sock;
		if ($redis) {
			my $key = 'badip.' . $src . ":$min";
			my $result = $redis->get($key);
			if (! defined($result) || $result < 6) {
				$redis->multi();
				$redis->incr($key);
				$redis->expire( $key, 60 );
				$redis->exec();
				$rlog->notice("Allowing $src to " . $r->unparsed_uri());
				$sock->send( "request.allowed:1|c\n" ) if defined $sock;
				return Apache2::Const::OK;
			} else {
				$rlog->notice("Forbid $src to " . $r->unparsed_uri() . " val " . $result );
				$sock->send( "request.blocked:1|c\n" ) if defined $sock;
				return Apache2::Const::FORBIDDEN;
			}
		}
	}
	
	$sock->send( "request.allowed:1|c\n" ) if defined $sock;
	my $name = $r->hostname();
	$name =~ tr/./-/;
	$sock->send( "request.hostname." . $name . ":1|c\n" ) if defined $sock;
	return Apache2::Const::OK;
}

1;
