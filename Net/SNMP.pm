
package Net::SNMP;

use IO::Socket;
use strict;
use Net::SNMP::BER;

sub new {
    my $class = shift;
    my %arg = @_;

    my $self = bless {
	net_snmp_reqid	 => 1,
	net_snmp_port	 => exists $arg{-port}
				? delete $arg{-port} : 161,
	net_snmp_retries => exists $arg{-retries}
				? delete $arg{-retries} : 4,
	net_snmp_timeout => exists $arg{-timeout}
				? delete $arg{-timeout} : 10,
    }, $class;

    $self->{net_snmp_host} = delete $arg{-host}
	if exists $arg{-host};

    $self->{net_snmp_community} = delete $arg{-community}
	if exists $arg{-community};

    $self->{'net_snmp_sock'} = new IO::Socket::INET(Proto => 'udp');

    $self;
}

sub get {
    my $self = shift;

    my $host = "localhost";
    my $port = 161;

    my $addr = sockaddr_in($port, inet_aton($host));

    my $reqid = $self->{'net_snmp_reqid'}++;

    my $pkt = new Net::SNMP::BER;
    my $id;
    my @vars;
    my $names = [ ".1.3.6.1.2.1.2.2.1.2.1" ];

    @vars = map {
	Net::SNMP::BER->new->encode(
	    SEQUENCE => [
		OBJECTID => $_,
		NULL	 => 0
	    ]
	)
    } @$names;

    $pkt->encode(
	SEQUENCE => [
	    INTEGER => 0,
	    STRING => "public",
	    GET_REQ_MSG => [
		INTEGER => $reqid,
		INTEGER => 0,
		INTEGER => 0,
#		SEQUENCE_OF => [ scalar(@$names),
#		    SEQUENCE => [
#			OBJECTID => $names,
#			NULL	 => 0
#		    ]
#		]
		SEQUENCE => [
		    BER => \@vars
		]
#		SEQUENCE => [
#		    map {
#			(SEQUENCE => [
#			    OBJECTID => $_,
#			    NULL	 => 0
#			])
#		    } @$names
#		]
	    ]
	]
    );

$pkt->dump;
$pkt->hexdump;
    $self->{'net_snmp_sock'}->send($pkt->buffer,0,$addr);
warn "$!";
my $buf = "";
    $self->{'net_snmp_sock'}->recv($buf,4096);
warn length($buf);
Net::SNMP::BER->new($buf)->dump;
}

sub set {
    my $self = shift;
}

sub getnext {
    my $self = shift;
}

1;
