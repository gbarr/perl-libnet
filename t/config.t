#!./perl -w

BEGIN {
    chdir 't' if -d 't';
    if ($ENV{PERL_CORE}) {
	@INC = '../lib';
    }
}

require "libnet_t.pl";

print "1..14\n";

use Net::Config;
ok( exists $INC{'Net/Config.pm'}, 'Net::Config should have been used' );
ok( keys %NetConfig, '%NetConfig should be imported' );

undef $NetConfig{'ftp_firewall'};
is( Net::Config->requires_firewall(), 0, 
	'requires_firewall() should return 0 without ftp_firewall defined' );

$NetConfig{'ftp_firewall'} = 1;
is( Net::Config->requires_firewall(''), -1,
	'... should return -1 without a valid hostname' );

delete $NetConfig{'local_netmask'};
is( Net::Config->requires_firewall('127.0.0.1'), 0,
	'... should return 0 without local_netmask defined' );

$NetConfig{'local_netmask'} = '127.0.0.1/24';
is( Net::Config->requires_firewall('127.0.0.1'), 0,
	'... should return false if host is within netmask' );
is( Net::Config->requires_firewall('192.168.10.0'), 1,
	'... should return true if host is outside netmask' );

# now try more netmasks
$NetConfig{'local_netmask'} = [ '127.0.0.1/24', '10.0.0.0/8' ];
is( Net::Config->requires_firewall('10.10.255.254'), 0,
	'... should find success with mutiple local netmasks' );
is( Net::Config->requires_firewall('192.168.10.0'), 1,
	'... should handle failure with multiple local netmasks' );

# now fool Perl into compiling this again.  HEY, LOOK OVER THERE!
my $path = $INC{'Net/Config.pm'};
delete $INC{'Net/Config.pm'};

# Net::Config populates %NetConfig from 'libnet.cfg', if possible
my $wrote_file = 0;

(my $cfgfile = $path) =~ s/Config.pm/libnet.cfg/;
if (open(OUT, '>' . $cfgfile)) {
	use Data::Dumper;
	print OUT Dumper({
		some_hosts => [ 1, 2, 3 ],
		time_hosts => 'abc',
		some_value => 11,
	});
	close OUT;
	$wrote_file = 1;
}

if ($wrote_file) {
	{
		local $^W;
		# and here comes Net::Config, again!  no import() necessary
		require $path;
	}

	is( $NetConfig{some_value}, 11, 
		'Net::Config should populate %NetConfig from libnet.cfg file' );
	is( scalar @{ $NetConfig{time_hosts} }, 1, 
		'... should turn _hosts keys into array references' );
	is( scalar @{ $NetConfig{some_hosts} }, 3, 
		'... should not mangle existing array references' );
	is( $NetConfig{some_hosts}[0], 1,
		'... and one last check for multivalues' );

} else {
	skip("could not write cfg file to $cfgfile: $!", 4);
}

is( \&Net::Config::is_external, \&Net::Config::requires_firewall,
	'is_external() should be an alias for requires_firewall()' );

END {
	1 while unlink ($cfgfile);
}
