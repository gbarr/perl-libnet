#!./perl -w

use Net::Config;
use Net::FTP;

unless(defined($NetConfig{ftp_testhost}) && $NetConfig{test_hosts}) {
    print "1..0\n";
    exit 0;
}

print "1..4\n";

$ftp = Net::FTP->new($NetConfig{ftp_testhost}, Debug => 0)
	or (print("not ok 1\n"), exit);

print "ok 1\n";

$ftp->login('anonymous') or print "not ";
print "ok 2\n";

$ftp->pwd or print "not ";
print "ok 3\n";

$ftp->quit or print "not ";
print "ok 4\n";
