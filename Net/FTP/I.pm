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

 syswrite($data, $buf, $size);
}

1;
