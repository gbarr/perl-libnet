package Net::SNMP::MIB;

{
    package Net::SNMP::MIB::enum;

    sub new {
	bless $_[1], $_[0];
    }

    sub name {
	my $me = shift;
	my $value = shift;
	my($name,$v);
	while(($name,$v) = each %$me) {
	    return $name if $value == $v;
	}
	return undef;
    }

    sub value {
	my $me = shift;
	my $name = shift;
	exists $me->{$name}
	    ? $me->{$name}
	    : undef;
    }
}

use Net::SNMP::BER;

use Symbol;

sub TYPE_OTHER		() {  0 }
sub TYPE_OBJID		() {  1 }
sub TYPE_OCTETSTR	() {  2 }
sub TYPE_INTEGER	() {  3 }
sub TYPE_NETADDR	() {  4 }
sub TYPE_IPADDR		() {  5 }
sub TYPE_COUNTER	() {  6 }
sub TYPE_GAUGE	  	() {  7 }
sub TYPE_TIMETICKS	() {  8 }
sub TYPE_OPAQUE		() {  9 }
sub TYPE_NULL		() { 10 }
sub TYPE_COUNTER64	() { 11 }
sub TYPE_BITSTRING	() { 12 }
sub TYPE_NSAPADDRESS	() { 13 }
sub TYPE_UINTEGER	() { 14 }

my $root = gensym;

sub root { bless $root };

sub add {
    my($parent,$name,$id,$type,$desc,$enum) = @_;
    my $me = gensym;
    if($parent) {
	${*$parent}{$name} = $me;
	${*$parent}[$id] = $me;
    }
    undef $parent if $parent == $root;
    my $h = ${*$me} = {
	parent	=> $parent,
	name	=> $name,
	id	=> $id,
	type	=> $type,
    };

    $h->{'enum'} = new Net::SNMP::MIB::enum($enum)
	if defined $enum;

    if(defined $desc) {
	chomp($desc);
	$h->{'desc'} = $desc . "\n";;
    }
    bless $me;
}

sub parent {
    my $me = shift;
    ${*$me}->{'parent'};
}

sub find {
    my $me = shift;
    my $name = shift;

    $me = $root if substr($name,0,1) eq ".";
    unless(ref($me)) {
	$me = $root;
	$name = ".1.3.6.1.2.1." . $name
	    unless substr($name,0,1) eq ".";
    }

    my @name = split(/\.+/,substr($name,1));
    while(@name) {
	my $bit = shift @name;
	if($bit =~ /\D/) {
	    return undef
		unless exists ${*$me}{$bit};
	    $me = ${*$me}{$bit};
	}
	else {
	    return undef
		unless defined ${*$me}[$bit];
	    $me = ${*$me}[$bit];
	}
    }
    $me;
}

sub id {
    my $me = shift;
    my @id = (${*$me}->{'id'});

    unshift @id, ${*$me}->{'id'}
	while($me = $me->parent);

    join(".","",@id);
}

sub fullname {
    my $me = shift;
    my @name = (${*$me}->{'name'});

    unshift @name, ${*$me}->{'name'}
	while($me = $me->parent);

    join(".","",@name);
}

sub type {
    my $me = shift;
    ${*$me}->{'type'};
}

sub name {
    my $me = shift;
    ${*$me}->{'name'};
}

sub description {
    my $me = shift;
    ${*$me}->{'desc'};
}

sub children {
    my $me = shift;
    grep { defined } @{*$me};
}

sub import {
    my $pkg = shift;
    my $mib;
    if(@_) {
	$mib = shift;
    }
    else {
	$mib = $INC{"Net/SNMP/MIB.pm"};
	substr($mib,-6) = "mib.pl";
    }
    require "$mib";
}

1;
