##
## Package to read/write on ASCII data connections
##

package Net::FTP::A;

use vars qw(@ISA $buf $VERSION);
use Carp;

require Net::FTP::dataconn;

@ISA = qw(Net::FTP::dataconn);
$VERSION = "1.09"; # $Id: //depot/libnet/Net/FTP/A.pm#9 $

sub new
{
 my $class = shift;
 my $data = $class->SUPER::new(@_) || return undef;

 ${*$data}{'net_ftp_last'} = " ";

 $data;
}

sub read
{
 my    $data 	= shift;
 local *buf 	= \$_[0]; shift;
 my    $size 	= shift || croak 'read($buf,$size,[$offset])';
 my    $timeout = @_ ? shift : $data->timeout;

 ${*$data} ||= "";
 my $l = 0;

 READ:
  {
   $data->can_read($timeout) or
	croak "Timeout";

   $buf = ${*$data};

   my $n = sysread($data, $buf, $size, length $buf);

   return undef
     unless defined $n;

   ${*$data}{'net_ftp_bytesread'} += $n;
   ${*$data}{'net_ftp_eof'} = 1 unless $n;

   ${*$data} = substr($buf,-1) eq "\015" ? chop($buf) : "";

   $buf =~ s/\015\012/\n/sgo;
   $l = length($buf);
   
   redo READ
     if($l == 0 && $n > 0);

   if($n == 0 && $l == 0)
    {
     $buf = ${*$data};
     ${*$data} = "";
     $l = length($buf);
    }
  }

 return $l;
}

sub write
{
 my    $data 	= shift;
 local *buf 	= \$_[0]; shift;
 my    $size 	= shift || croak 'write($buf,$size,[$timeout])';
 my    $timeout = @_ ? shift : $data->timeout;

 $data->can_write($timeout) or
	croak "Timeout";

 (my $tmp = substr($buf,0,$size)) =~ s/\n/\015\012/sg;

 # If the remote server has closed the connection we will be signal'd
 # when we write. This can happen if the disk on the remote server fills up

 local $SIG{PIPE} = 'IGNORE';

 my $len = length($tmp);
 my $off = 0;
 my $wrote = 0;

 while($len) {
   $off += $wrote;
   $wrote = syswrite($data, substr($tmp,$off), $len);
   return undef
     unless defined($wrote);
   $len -= $wrote;
 }

 return $size;
}

1;
