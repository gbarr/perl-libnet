#

package Net::Domain;

use Carp;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(hostname domainname hostdomain);

$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);
sub Version { $VERSION }

=head1 NAME

Net::Domain - Attempt to evaluate the current host's internet name and domain

=head1 SYNOPSIS

  use Net::Domain qw(hostname domainname hostdomain);

=head1 DESCRIPTION

Using various methods B<attempt> to find the FQDN of the current host. From
this find the hostname and the hostdomain.

=cut

$host = undef;
$domain = undef;
$fqdn = undef;

#
# Try every conceivable way to get hostname.
# 

sub _hostname {
# by David Sundstrom   sunds@asictest.sc.ti.com
#    Texas Instruments

 # method 1 - we already know it

 return $host if(defined $host);

 # method 2 - syscall is preferred since it avoids tainting problems
 eval {
  {
   package main;
   require "syscall.ph";
  }
  my $tmp = "\0" x 65; ## preload scalar
  $host = (syscall(&main::SYS_gethostname, $tmp, 65) == 0) ? $tmp : undef;
 }


 # method 3 - trusty old hostname command
 || eval {
  chop($host = `(hostname) 2>/dev/null`); # bsdish
 }


 # method 4 - sysV/POSIX uname command (may truncate)
 || eval {
  chop($host = `uname -n 2>/dev/null`); ## sysVish && POSIXish
 }

 
 # method 5 - Apollo pre-SR10
 || eval {
  $host = (split(/[:\. ]/,`/com/host`,6))[0];
 }

 || eval {
  $host = "";
 };
 
 # remove garbage 
 $host =~ s/[\0\r\n]+//g;
 $host =~ s/(\A\.+|\.+\Z)//g;
 $host =~ s/\.\.+/\./;

 $host;
}

sub _hostdomain {

 ##
 ## return imediately if we have already found the domainname;
 ##

 return $domain if(defined $domain);

 ##
 ## First attempt, just try hostname and system calls
 ##

 my $host = _hostname();
 my($dom,$site,@hosts);
 local($_);

 @hosts = ($host,"localhost");

 unless ($host =~ /\./){
  eval {
   chop($dom = `domainname 2>/dev/null`);
  };
  unshift(@hosts, "$host.$dom") if ($dom ne "");
 }


 foreach (@hosts) { # Attempt to locate FQDN
  my @info = gethostbyname($_);
  if(@info) {
   foreach $site ($info[0], split(/ /,$info[1])) { # look at real name & aliases
    if(rindex($site,".") > 0) {
     ($domain = $site) =~ s/\A[^\.]+\.//; # Extract domain from FQDN
     return $domain;
    }
   }
  }
 }

 ##
 ## try looking in /etc/resolv.conf
 ##

 local *RES;

 if(open(RES,"/etc/resolv.conf")) {
  while(<RES>) {
   if(/\A\s*(?:domain|search)\s+(\S+)/) {
    $domain = $1;
   }
  }
  close(RES);

  return $domain if(defined $domain);
 }

 ##
 ## Look for environment variable
 ##

 return $domain = $ENV{DOMAIN} if(defined $ENV{DOMAIN});

 $domain =~ s/[\r\n\0]+//g;
 $domain =~ s/(\A\.+|\.+\Z)//g;
 $domain =~ s/\.\.+/\./g;

 $domain;
}

=head2 domainname()

Identify and return the FQDN of the current host.

=cut

sub domainname {

 return $fqdn if(defined $fqdn);

 _hostname();
 _hostdomain();

 my @host   = split(/\./, $host);
 my @domain = split(/\./, $domain);
 my @fqdn   = ();

 ##
 ## Determine from @host & @domain the FQDN
 ##

 my @d = @domain;
 
 LOOP:
  while(1) {
   my @h = @host;
   while(@h) {
    my $tmp = join(".",@h,@d);
    if((gethostbyname($tmp))[0]) {
     @fqdn = (@h,@d);
     $fqdn = $tmp;
     last LOOP;
    }
    pop @h;
   }
   last unless shift @d;
  }

 if(@fqdn) {
  $host = shift @fqdn;
  until((gethostbyname($host))[0]) {
   $host .= "." . shift @fqdn;
  }
  $domain = join(".", @fqdn);
 }
 else {
  undef $host;
  undef $domain;
  undef $fqdn;
 }

 $fqdn;
}

=head2 hostname()

Returns the smallest part of the FQDN which can be used to identify the host.

=cut

sub hostname {
 domainname() unless(defined $host);
 return $host;
 
}

=head2 hostdomain()

Returns the remainder of the FQDN after the I<hostname> has been removed

=cut

sub hostdomain {
 domainname() unless(defined $domain);
 return $domain;
}

=head1 COPYRIGHT

Copyright (c) 1995 Graham Barr. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 REVISION

$Revision: 1.6 $

=head1 AUTHOR

Graham Barr <bodg@tiuk.ti.com>

=cut


1; # Keep require happy

__END__

$Log: Domain.pm,v $
# Revision 1.6  1995/11/16  11:57:04  gbarr
# Changed package name to Net::Domain
#
# Revision 1.6  1995/11/16  11:57:04  gbarr
# Changed package name to Net::Domain
#
# Revision 1.5  1995/09/11  10:55:55  gbarr
# modified code to check all host name aliases
# for a FQDN
#
# Revision 1.5  1995/09/11  10:55:55  gbarr
# modified code to check all host name aliases
# for a FQDN
#
# Revision 1.4  1995/09/06  06:08:42  gbarr
# Applied patch from Matthew.Green@fulcrum.com.au to chop
# results from `` commands
#
# Revision 1.3  1995/09/04  15:03:51  gbarr
# changed the /etc/resolve.conf code to look for search and
# domain parameters and use the last one found
#
# Revision 1.2  1995/09/04  11:22:59  gbarr
# Added documentation
#
# Revision 1.1  1995/08/31  20:35:30  gbarr
# Initial revision
#
