#!./perl -w

use Net::Config;
use Net::NNTP;

unless(@{$NetConfig{nntp_hosts}} && $NetConfig{test_hosts}) {
    print "1..0\n";
    exit 0;
}

print "1..4\n";

my $i = 1;

$nntp = Net::NNTP->new(Debug => 0)
	or (print("not ok 1\n"), exit);

print "ok 1\n";

my $grp;
foreach $grp (qw(test alt.test control news.announce.newusers)) {
    @grp = $nntp->group($grp);
    last if @grp;
}
print "not " unless @grp;
print "ok 2\n";


if(@grp && $grp[2] > $grp[1]) {
    $nntp->head($grp[1]) or print "not ";
}
print "ok 3\n";

if(@grp) {
    $nntp->quit or print "not ";
}
print "ok 4\n";

