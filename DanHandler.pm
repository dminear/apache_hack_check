package ModPerl::DanHandler;
use strict;
use warnings;
use FileHandle;
use IO::Socket::INET;

use Apache2::Log;
use Apache2::RequestRec ();
use Apache2::Connection ();
#use Redis::Client;
use Redis;

use Apache2::Const -compile => qw(FORBIDDEN OK :log);

my $redis;

BEGIN {
#mkdir "/var/www/bad_ips";
#chmod 0777, "/var/www/bad_ips";
$redis = Redis->new(host=>'localhost', port=>6379);
$redis->auth("123qwe!@#QWE");
}

#my $ipstor = "/var/www/bad_ips";

my $sock = IO::Socket::INET->new(PeerPort => 8125,
				PeerAddr => '127.0.0.1',
				Proto => 'udp');

sub handler {
	my $r = shift;
	
	#my $str = $r->connection->remote_ip();
	my $str = $r->connection->client_ip();
	my $rlog = $r->log;

	if ( $str =~ /71.165/ || 
		$str =~ /192.168.0/  ||
		$str =~ /130.76/  ||
		$str =~ /108.0/ ) {
		return Apache2::Const::OK;
	}

	$redis->auth("123qwe!@#QWE");
	# if there is an attempt to access "zencart/admin", then put the ip on the block list
	if ($r->unparsed_uri() =~ /zencart\/admin$/ ||
		$r->unparsed_uri() =~ /zencart\/+admin\/+/ ||
		$r->unparsed_uri() =~ /phpbb2/i  ||
		$r->unparsed_uri() =~ /wp-login/  ||
		$r->unparsed_uri() =~ /wordpress\/xmlrpc.php/  ||
		$r->unparsed_uri() =~ /phpMyAdmin/ ) {
		#$r->log_error("BAD IP: $str");
		$sock->send( "hacker.unparsed_uri." . $r->unparsed_uri() . ":1|c\n" ) if defined $sock;

		#my $fh = FileHandle->new( "> $ipstor/$str");
		#if (defined $fh) {
		#	print $fh time();
		#	$fh->close;
		#}

		$rlog->notice("Bad IP ", $str, " putting in redis");
		$redis->hincrby( 'badips', $str, 1 );
	}
	
	# check the block list
	#if (-e "$ipstor/$str") {
	if ($redis->hexists( 'badips', $str )) {
		$sock->send( "request.blocked:1|c\n" ) if defined $sock;
		$rlog->notice("Bad IP ", $str, " blocked");
		return Apache2::Const::FORBIDDEN;
	} else {
		$sock->send( "request.allowed:1|c\n" ) if defined $sock;
		my $name = $r->hostname();
		$name =~ tr/./-/;
		$sock->send( "request.hostname." . $name . ":1|c\n" ) if defined $sock;
		#$rlog->notice("OK IP ", $str, " permitting");
		return Apache2::Const::OK;
	}
}
1;
