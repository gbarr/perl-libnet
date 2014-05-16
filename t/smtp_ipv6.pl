use strict;
use warnings;
use Test::More;
use File::Temp 'tempfile';
use Net::SMTP;

my $debug = 1; # Net::SMTP->new( Debug => .. )

my $inet6class = Net::SMTP->can_inet6;
plan skip_all => "no IPv6 support found in Net::SMTP" if ! $inet6class;

plan skip_all => "fork not supported on this platform"
  if grep { $^O =~m{$_} } qw(MacOS VOS vmesa riscos amigaos);

my $srv = $inet6class->new(
  LocalAddr => '::1',
  Listen => 10
);
plan skip_all => "cannot create listener on ::1: $!" if ! $srv;
my $saddr = "[".$srv->sockhost."]".':'.$srv->sockport;
diag("server on $saddr");

plan tests => 1;

defined( my $pid = fork()) or die "fork failed: $!";
exit(smtp_server()) if ! $pid;

my $cl = Net::SMTP->new($saddr, Debug => $debug);
diag("created Net::SMTP object");
if (!$cl) {
  fail("IPv6 SMTP connect failed");
} else {
  $cl->quit;
  pass("IPv6 success");
}
wait;

sub smtp_server {
  my $cl = $srv->accept or die "accept failed: $!";
  print $cl "220 welcome\r\n";
  while (<$cl>) {
    my ($cmd,$arg) = m{^(\S+)(?: +(.*))?\r\n} or die $_;
    $cmd = uc($cmd);
    if ($cmd eq 'QUIT' ) {
      print $cl "250 bye\r\n";
      last;
    } elsif ( $cmd eq 'HELO' ) {
      print $cl "250 localhost\r\n";
    } elsif ( $cmd eq 'EHLO' ) {
      print $cl "250-localhost\r\n".
	"250 HELP\r\n";
    } else {
      diag("received unknown command: $cmd");
      print "500 unknown cmd\r\n";
    }
  }

  diag("SMTP dialog done");
}
