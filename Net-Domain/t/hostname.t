
use Net::Domain qw(hostname domainname hostdomain);

print "1..1\n";

$domain = domainname();

if(defined $domain && $domain ne "") {
 print "ok 1\n";
}
else {
 print "not ok 1\n";
}
