
package Net::SNPP::HylaFAX;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Net::SNPP;
use Carp;

$VERSION = do { my @r=(q$Revision: 0.1 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r};

@ISA = qw(Exporter Net::SNPP);

@EXPORT = @Net::SNPP::EXPORT;
@EXPORT_OK = qw(NOTIFY_NONE NOTIFY_DONE NOTIFY_REQUEUE MODEM_DEVICE MODEM_CLASS);
%EXPORT_TAGS = (
	NOTIFY => [qw(NOTIFY_NONE NOTIFY_DONE NOTIFY_REQUEUE)],
	MODEM  => [qw(MODEM_DEVICE MODEM_CLASS)],
);

sub NOTIFY_NONE    () { 1 }
sub NOTIFY_DONE    () { 2 }
sub NOTIFY_REQUEUE () { 4 }

sub MODEM_CLASS  () { 1 }
sub MODEM_DEVICE () { 2 }

sub jqueue
{
 @_ == 2 or croak 'usage: $snpp->jqueue( BOOLEAN )';
 my $snpp = shift;
 my $arg = $_[0] ? "YES" : "NO";

 $snpp->_SITE('JQUEUE', $arg)->response() == CMD_OK;
}

sub from_user
{
 @_ == 2 or croak 'usage: $snpp->from_user( MAIL_ADDRESS )';
 my $snpp = shift;

 ($snpp->_SITE('FROMUSER',@_)->response == CMD_OK)
	? ($snpp->message =~ /"([^"]+)"/)[0]
	: undef;
}

my %modem = ( DEVICE => MODEM_DEVICE, CLASS => MODEM_CLASS);

sub modem
{
 @_ == 2 or croak 'usage: $snpp->modem( [MODEM_DEVICE|MODEM_CLASS] )';
 my $snpp = shift;
 my $modem = shift;
 my $arg = $modem == MODEM_DEVICE
		? "DEVICE"
		: $modem == MODEM_CLASS
			? "CLASS"
			: croak 'Unknown modem type';

 my $ret = ($snpp->_SITE('MODEM',$arg)->response == CMD_OK)
	? ($snpp->message =~ /"([^"]+)"/)[0]
	: undef;

 if(defined $ret)
  {
   $ret = uc $ret;
   $ret = $modem{$ret} || croak "Unknown modem type '$ret'";
  }

 $ret;
}

my $i = 0;
my %notify = map { $_ => (1 << $i++) } qw(NONE DONE REQUEUE);

sub notify
{
 @_ == 2 or croak 'usage: $snpp->notify( NOTIFY_LEVEL )';
 my $snpp = shift;
 my $arg = shift;
 my @arg = ();

 croak 'Bad notify argument'
	if $arg < 1 || $arg == 3 || $arg == 5 || $arg > 6;

 push(@arg,"NONE") if $arg & 1;
 push(@arg,"DONE") if $arg & 2;
 push(@arg,"REQUEUE") if $arg & 4;

 my $str = ($snpp->_SITE('NOTIFY',join("+",@arg))->response == CMD_OK)
	? ($snpp->message =~ /"([^"]+)"/)[0]
	: undef;

 my $val = undef;

 if($str)
  {
   $val = 0;
   map { $val |= $notify{$_} } split(/\+/, $str)
  }

 $val;
}

sub notify_addr
{
 my $snpp = shift;

 ($snpp->_SITE('MAILADDR',@_)->response == CMD_OK)
	? ($snpp->message =~ /"([^"]+)"/)[0]
	: undef;
}

1;
