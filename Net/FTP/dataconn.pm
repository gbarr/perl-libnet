##
## Generic data connection package
##

package Net::FTP::dataconn;

use Carp;
use vars qw(@ISA $timeout);
use Net::Cmd;

@ISA = qw(IO::Socket::INET);

sub abort
{
 my $data = shift;
 my $ftp  = ${*$data}{'net_ftp_cmd'};

 $ftp->abort; # this will close me
}

sub _close
{
 my $data = shift;
 my $ftp  = ${*$data}{'net_ftp_cmd'};

 $data->SUPER::close();

 delete ${*$ftp}{'net_ftp_dataconn'}
    if exists ${*$ftp}{'net_ftp_dataconn'} &&
        $data == ${*$ftp}{'net_ftp_dataconn'};
}

sub close
{
 my $data = shift;
 my $ftp  = ${*$data}{'net_ftp_cmd'};

 $data->_close;

 $ftp->response() == CMD_OK &&
    $ftp->message =~ /unique file name:\s*(\S*)\s*\)/ &&
    (${*$ftp}{'net_ftp_unique'} = $1);

 $ftp->status == CMD_OK;
}

sub _select
{
 my    $data 	= shift;
 local *timeout = \$_[0]; shift;
 my    $rw 	= shift;

 my($rin,$win);

 return 1 unless $timeout;

 $rin = '';
 vec($rin,fileno($data),1) = 1;

 $win = $rw ? undef : $rin;
 $rin = undef unless $rw;

 my $nfound = select($rin, $win, undef, $timeout);

 croak "select: $!"
	if $nfound < 0;

 return $nfound;
}

sub can_read
{
 my    $data    = shift;
 local *timeout = \$_[0];

 $data->_select($timeout,1);
}

sub can_write
{
 my    $data    = shift;
 local *timeout = \$_[0];

 $data->_select($timeout,0);
}

sub cmd
{
 my $ftp = shift;

 ${*$ftp}{'net_ftp_cmd'};
}

1;
