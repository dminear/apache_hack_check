#!/usr/bin/perl -w

use strict;
use FileHandle;
use Cache::Memcached;
use Data::Dumper;
use Redis::Client;
use JSON;

#print "Transfer-Encoding: chunked\n";
print "Content-type: text/plain\n\n";

my $debug = 1;

=comment

my $memd = new Cache::Memcached {
        'servers' => [ "localhost:11211" ],
        'debug' => 0,
        'namespace' => 'badip',
        };
=cut

my $redis = Redis::Client->new( 'localhost', 6379 );
$redis->auth($ENV{REDIS_PW});
$redis->select(10);
$redis->expire( 'badips_country', 60*60*24*30 );

#opendir( my $dh, "/var/www/bad_ips" ) || die "Cannot open dir:$!";
#my @ips = grep { /^\d+\.\d+\.\d+.\d+/ } readdir($dh);
#closedir $dh;

my @ips = $redis->keys( 'badip.*' );
print Dumper( \@ips ) if $debug;
print "There are " . @ips . " bad IP addresses.\n" if $debug;
my $countries = {};

foreach (@ips) {
	/badip.(.*)$/;
	$_ = $1;
	if (/(\d+\.\d+\.\d+\.\d+)/) {
		my $c;
		my $j;

		#if ($c = $memd->get($_)) { # got key
		if ($j = $redis->hget('badips_country', $_)) { # got key
			print "key $_ in badips_country\n" if $debug;
			$c = decode_json( $j );
		} else {	# need to get info
			my $cmd = "curl -s http://api.hostip.info/get_html.php?ip=$_" ;
			sleep 1;
			my @d = `$cmd`;
			if (@d == 0) {
				print "skipping $_ bad response\n" if $debug;
				next;
			}
			chomp @d;
			my %e = map { /(.*)\s*:\s*(.*)/; $1,$2 } @d;
			#$memd->set($_, $c, 60*60*24*29); 	# store for 29 days
			print Dumper( \%e ) if $debug;
			$c = \%e;
			$j = encode_json( $c );
			print Dumper( \$j ) if $debug;
			$redis->hset('badips_country', $_, $j );
		}
# data format looks like:
# $c = [
#          'Country: CHINA (CN)
# ',
#          'City: Putian
# ',
#          'IP: 110.86.186.49
# '
#        ];
=comment

		my %data = map { my @s = split(/:/, $_); $s[0], $s[1]; } @$c;
		print "data hash is " . Dumper( \%data )if $debug;
		my $country = $data{"Country"};
		chomp $country;
		$country =~ s/^\s+//;
		$country = $c->{"Country"};
=cut

		$countries->{$c->{"Country"}}++;
	} else {
		warn "bad ip $_\n";
	}
}

# now output the country counts
print "BAD IPS PER COUNTRY\nCOUNTRY\tCOUNT\n";
foreach (sort keys %$countries) {

	print $countries->{$_} . "\t$_\n";
}


=comment
			my $fh = FileHandle->new("> processed/$_") || die "cannot write file: $!\n";
			print $fh @d;
			$fh->close;

		my $fh = FileHandle->new("> $_" ) || die "cannot open file: $!\n";
		if (defined $fh) {
			print $fh time;
			$fh->close;
		}
=cut
