##
## Package to read/write on BINARY data connections
##

package Net::FTP::I;

use vars qw(@ISA $buf);
use Carp;

require Net::FTP::dataconn;

@ISA = qw(Net::FTP::dataconn);

sub read
{
 my    $data 	= shift;
 local *buf 	= \$_[0]; shift;
 my    $size    = shift || croak 'read($buf,$size,[$timeout])';
 my    $timeout = @_ ? shift : $data->timeout;

 $data->can_read($timeout) or
	croak "Timeout";

 my $n = sysread($data, $buf, $size);

 ${*$data}{'net_ftp_bytesread'} += $n if $n > 0;

 $n;
}

sub write
{
 my    $data    = shift;
 local *buf     = \$_[0]; shift;
 my    $size    = shift || croak 'write($buf,$size,[$timeout])';
 my    $timeout = @_ ? shift : $data->timeout;

 $data->can_write($timeout) or
	croak "Timeout";

 # If the remote server has closed the connection we will be signal'd
 # when we write. This can happen if the disk on the remote server fills up

 local $SIG{PIPE} = 'IGNORE';

 syswrite($data, $buf, $size);
}

1;
