# Net::TFTP.pm
#
# Copyright (c) 1998 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::TFTP;

use strict;
use vars qw($VERSION);
use IO::Socket;
use IO::Select;
use IO::File;

$VERSION = "0.02";

sub RRQ	  () { 01 } # read request
sub WRQ	  () { 02 } # write request
sub DATA  () { 03 } # data packet
sub ACK	  () { 04 } # acknowledgement
sub ERROR () { 05 } # error code

sub new {
    my $pkg = shift;
    my $host = shift;
    my %arg = @_;

    bless {
	net_tftp_host    => $host,
	net_tftp_timeout => $arg{'Timeout'} || 5,
	net_tftp_rexmit  => $arg{'Rexmit'} || 5,
	net_tftp_mode    => exists $arg{'Mode'} ? $arg{'Mode'} : 'netascii',
	net_tftp_port    => exists $arg{'Port'} ? $arg{'Port'} : 'tftp(69)',
    }, $pkg;
}

sub timeout {
    my $self = shift;
    $self->{'net_tftp_timeout'} = 0 + shift;
}

sub rexmit {
    my $self = shift;
    $self->{'net_tftp_rexmit'} = 0 + shift;
}

sub ascii {
    my $self = shift;
    $self->{'net_tftp_mode'} = "netascii";
}

sub binary {
    my $self = shift;
    $self->{'net_tftp_mode'} = "octet";
}

sub get {
    my $self = shift;
    my $file = shift;
    my %arg = (
	Mode    => $self->{'net_tftp_mode'},
	Port    => $self->{'net_tftp_port'},
	Host    => $self->{'net_tftp_host'},
	Rexmit  => $self->{'net_tftp_rexmit'},
	Timeout => $self->{'net_tftp_timeout'},
	@_
    );
    my($host,$port,$proto) = @arg{'Host','Port'};

    $arg{'Mode'} = lc($arg{'Mode'});
    $arg{'Mode'} = "netascii" unless $arg{'Mode'} eq "octet";
    
    # This is naughty as _sock_info is private, but I maintain IO::Socket
    ($host,$port,$proto) = IO::Socket::INET::_sock_info($host,$port,'udp');

    my $sock = IO::Socket::INET->new(Proto => 'udp');
    my $mode = $arg{'Mode'};
    my $pkt = pack("n a* c a* c", RRQ, $file, 0, $mode, 0);

    $sock->send($pkt,0,pack_sockaddr_in($port,inet_aton($host)));

    my $sel = IO::Select->new($sock);
    my $io = Net::TFTP::IO->new($sock,$sel, $mode eq "netascii",@arg{'Rexmit','Timeout'});

    return $io
	unless exists $arg{'Local'};

    my $local = IO::File->new($arg{'Local'},O_WRONLY|O_CREAT);

    while(sysread($io,$pkt,512)) {
	syswrite($local,$pkt,length($pkt));
    }

    close($local);
}

sub put {
    require Carp;
    Carp::croak("Net::TFTP::put - unimplemented");
}

package Net::TFTP::IO;

sub new {
    my $pkg = shift;
    my $io = new IO::Handle;
    tie *$io, "Net::TFTP::IO",
	{
	    'sock' => $_[0],
	    'sel'  => $_[1],
	    'ascii' => $_[2],
	    'rexmit' => $_[3],
	    'timeout' => $_[4],
	    'obuf' => '',
	    'ocr' => 0,
	    'ibuf' => '',
	    'icr' => 0,
	    'blk' => 1,
	};
    $io;
}

sub TIEHANDLE {
    my $pkg = shift;
    bless shift , $pkg;
}

sub PRINT {
    my $self = shift;
    my $buf = join("",@_);
    $self->WRITE($buf,length($buf));
}

sub READLINE {
    my $self = shift;

    if(defined $self->{'ibuf'}) {
	while(1) {
	    return $1 
		if($self->{'ibuf'} =~ s/^([^\n]*\n)//s);

	    my $res = _read($self);

	    next if $res > 0;
	    last if $res < 0;

	    return delete $self->{'ibuf'};
	}
	delete $self->{'ibuf'};
    }

    return undef;
}

# returns
# >0 size of data read
# 0  eof
# <0 error

sub _read {
    my $self = shift;
    my $ret = 0;

    return 0
	unless $self->{'sel'};

    my $timeout = $self->{'timeout'};

    while($timeout > 0) {

	if($self->{'sel'}->can_read($self->{'rexmit'} || 1)) {
	    my $pkt='';

	    $self->{'sock'}->recv($pkt,516,0);
	    my($code,$blk) = unpack("nn",$pkt);
	    $self->{'blk'} = $blk;
	    if($code == Net::TFTP::DATA) {
		my $len = length($pkt);
		if($self->{'ascii'}) {
		    if($self->{'icr'}) {
			if(substr($pkt,4,1) eq "\012") {
			    substr($pkt,4,1) = "\n";
			}
			else {
			    $self->{'ibuf'} .= "\015";
			}
		    }
		    if($len == 516 && substr($pkt,-1) eq "\015") {
			substr($pkt,-1) = "";
			$self->{'icr'} = 1;
		    }
		    else {
			$self->{'icr'} = 0;
		    }
		    substr($pkt,4) =~ s/\015\012/\n/sog;
		}
		$self->{'ibuf'} .= substr($pkt,4);
		$self->{'sock'}->send(pack("nn", Net::TFTP::ACK,$blk));

		$ret = length($pkt) - 4;
		$self->{'sock'} = $self->{'sel'} = undef
		    if ( $len < 516);
		last;
	    }
	    else {
	        return -1;
		die substr($pkt,4);
	    }
	}
	else {
	    $timeout -= $self->{'rexmit'};
	    return -1
		if $timeout <= 0;
	}
    }
    $ret;
}

sub READ {
    # $self, $buf, $len, $offset

    my $self = shift;
    my $ret;

    return 0
	unless exists $self->{'ibuf'};

    while(($ret = length($self->{'ibuf'})) < $_[1]) {
	last unless _read($self);
    }

    $ret = $_[1] if $_[1] < $ret;

    if($ret) {
	if($_[2]) {
	    substr($_[0],$_[2]) = substr($self->{'ibuf'},0,$ret);
	}
	else {
	    $_[0] = substr($self->{'ibuf'},0,$ret);
	}
    }

    substr($self->{'ibuf'},0,$ret) = "";

    delete $self->{'ibuf'}
	if $ret < $_[1];

    $ret;
}

sub DESTROY {} 

sub _write {
    my $self = shift;
    my $buf = substr($self->{'obuf'},0,512);
    substr($self->{'obuf'},0,512) = '';
}

sub WRITE {
    # $self, $buf, $len, $offset
    my $self = shift;
    my $buf = substr($_[0],$_[2] || 0,$_[1]);
    my $offset = 0;
    if($self->{'ocr'} && substr($buf,0,1) eq "\012") {
	substr($buf,0,1) = ' ';
	$offset = 1;
    }
    $self->{'ocr'} = substr($buf,-1) eq "\015";
    $buf =~ s/\015\012|\012|\015/\015\012/sg;
    $self->{'obuf'} .= substr($buf,$offset);
    if(length($self->{'obuf'} >= 512)) {
	_write($self);
    }
    $_[1];
}

sub CLOSE {
    my $self = shift;

#    _write($self)
#	if(length($self->{'obuf'}));

    close($self->{'sock'});
}

1;


__END__

=head1 NAME

Net::TFTP - TFTP Client class

=head1 SYNOPSIS

    use Net::TFTP;
    
    $tftp = Net::TFTP->new("some.host.name");
    
    $tftp->get("somefile", -local => "outfile");

    $tftp->quit;

=head1 DESCRIPTION

C<Net::TFTP> is a class implementing a simple TFTP client in Perl as described
in RFC++++.

=head1 CONSTRUCTOR

=over 4

=item new ( [ HOST ] [, OPTIONS ])

=back

=head1 METHODS

Unless otherwise stated all methods return either a I<true> or I<false>
value, with I<true> meaning that the operation was a success. When a method
states that it returns a value, failure will be returned as I<undef> or an
empty list.

=over 4

=back

=head1 AUTHOR

Graham Barr <gbarr@pobox.com>

=head1 COPYRIGHT

Copyright (c) 1998 Graham Barr. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
