# Net::SMTP.pm
#
# Copyright (c) 1995 Graham Barr <Graham.Barr@tiuk.ti.com>. All rights
# reserved. This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::SMTP;

=head1 NAME

SMTP - implements SMTP Client

=head1 SYNOPSIS

use Net::SMTP;

$smtp = Net::SMTP->new(<host>,[%args]);

=head1 DESCRIPTION

This package provides a class object which can be used for connecting to remote
SMTP servers and transfering mail.

=head2 NOTE: C<This Documentation is VERY incomplete>

=cut

require 5.001;
use Socket 1.3;
use Carp;

$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);
sub Version { $VERSION }

$socksym = "smtp00000";

##
## Really WANT FileHandle::new to return this !!!
##
sub gensym {\*{"Net::SMTP::" . $socksym++}}

sub new {
 my $pkg  = shift;
 my $host = shift;
 my %arg  = @_;

 my($port,$protoname) = (getservbyname('smtp', ''))[2,3];
 my $proto = getprotobyname($protoname); # probably will be 'tcp'
 my $sock = gensym();
 my $destaddr = inet_aton($host) or
    croak "unknown host $host";

 croak "socket: $!" unless(socket($sock, AF_INET, SOCK_STREAM, $proto));

 $port = $arg{Port} if(defined $arg{Port});

 my $sin = sockaddr_in($port,$destaddr);

 croak "connect: $!" unless(connect($sock, $sin));

 my $me = {
           SOCK    => $sock, 			# Command socket connection

           Resp    => [], 			# Last response text
           Code    => 0, 			# Last response code

           Timeout => $arg{Timeout} || 120, 	# Timeout value
           Debug   => $arg{Debug} || 0 		# Output debug information
          };

 bless $me, $pkg;


 select((select($sock), $| = 1)[$[]);

 unless($me->response() == 2) {
  close($sock);
  undef $me;
  return undef;
 }

 ($me->{Domain}) = $me->message =~ /\A\s*(\S+)/;

 $me->hello($arg{Hello} || "");

 $me;
}

##
## User interface methods
##

=item * debug( [level] )

Turn the printing of debug information on/off for this object. If no
argument is given then the current state is returned. Otherwise the
state is changed to C<level> and the previous state returned.

=cut

sub debug {
 my $me = shift;
 my $debug = $me->{Debug};
 
 $me->{Debug} = 0 + shift if(@_);

 $debug;
}

=item * quit

Send the QUIT command to the remote SMTP server and close the socket connection.

=cut

sub quit {
 my $me = shift;

 return undef unless($me->QUIT);

 close($me->{SOCK});
 delete $me->{SOCK};

 return 1;
}

sub domain {
 my $me = shift;
 return $me->{Domain} || undef;
}

sub hello { 
 my $me = shift;
 my $domain = shift;

 $domain = eval {
                 require Net::Domain;
                 Net::Domain::domainname();
                } unless(defined $domain && $domain);

 my $ok = $me->HELO($domain || "");
 my $remote = undef;

 ($remote) = $me->message =~ /\A(\S+)/ if($ok);

 return $remote;
}

sub mail { shift->MAIL(shift || "") }

sub reset         { shift->RSET() }
sub send          { shift->SEND(shift || "") }
sub send_or_mail  { shift->SOML(shift || "") }
sub send_and_mail { shift->SAML(shift || "") }

sub recipient
{
 my $smtp = shift;
 my $ok = 1;

 while($ok && scalar(@_)) {
  $smtp->RCPT(shift);
 } 

 $ok;
}

*to = \&recipient;

sub data {
 my $me = shift;
 my $data = shift;

 return 0 unless(defined $data);

 $data = [$data] unless(ref($data));

 my $sock = $me->{SOCK};

 return 0 unless($me->DATA());

 local $_;

 foreach (@$data)
  {
   $me->SMTPWRITE($_);
  }

 print $sock ".\r\n";

 2 == $me->response();
}

sub SMTPWRITE {
 my $me = shift;
 my $line = shift;
 my $sock = $me->{SOCK};
 my $debug = $me->debug;
 local $_;

 foreach (split(/\r?\n/, $line))
  {
   my $dot = (/\A\./o) ? "." : "";

   print STDERR $dot,$_,"\n" if($debug > 1);
   print $sock $dot,$_,"\r\n";
  }
}

sub expand {
 my $me = shift;

 if($me->EXPN(@_)) {
  my(@r);
  foreach $ln (@{$me->{Resp}}) {
    push(@r, [ $1, $2 ]) if($ln =~ /\A\s*(\S.*\S)?\s*<([^>]*)>/);
  }
  return @r;
 }

 return undef;
}

sub verify {
 my $me = shift;

 if($me->VRFY(@_)) {
  my(@r);
  foreach $ln (@{$me->{Resp}}) {
    push(@r, [ $1, $2 ]) if($ln =~ /\A\s*(\S.*\S)?\s*<([^>]*)>/);
  }
  return @r;
 }

 return undef;
}

sub help {
 my $me = shift;

 return $me->message if($me->HELP(@_));

 return undef;
}

##
## Communication methods
##

sub timeout {
 my $me = shift;
 my $timeout = $me->{Timeout};

 $me->{Timeout} = 0 + shift if(@_);

 $timeout;
}

sub message {
 my $me = shift;
 join("\n", @{$me->{Resp}});
}

sub ok {
 my $me = shift;
 my $code = $me->{Code} || 0;

 0 < $code && $code < 400;
}

sub cmd {
 my $me = shift;
 my $sock = $me->{SOCK};


 if(scalar(@_)) {     
  my $cmd = join(" ", @_);

  print $sock $cmd,"\r\n";

  printf STDERR "$me>> %s\n", $cmd if($me->debug);
 }

 $me->response();                                          
}

sub response {
 my $me = shift;
 my $sock = $me->{SOCK};
 my $timeout = $me->{Timeout};
 my($code,@resp,$rin,$rout,$partial,@buf,$buf);

 $rin = '';
 vec($rin,fileno($sock),1) = 1;
 $more = 0;
 @resp = ();
 $partial = '';
 $buf = "";

 do {
  if (($timeout==0) || select($rout=$rin, undef, undef, $timeout)) {
   unless(sysread($sock, $buf, 1024)) {
    carp "Unexpected EOF on command channel";
    return undef;
   } 

   substr($buf,0,0) = $partial;    ## prepend from last sysread

   @buf = split(/\r?\n/, $buf);  ## break into lines

   $partial = (substr($buf, -1, 1) eq "\n") ? ''
                                            : pop(@buf); 

   foreach $cmd (@buf) {
    print STDERR "$me<< $cmd\n" if($me->debug);

    ($code,$more) = ($1,$2) if $cmd =~ /^(\d\d\d)(.)/;
    push(@resp,$');
   } 
  }
  else {
   carp "$me: Timeout" if($me->debug);
   return undef;
  }
 } while(length($partial) || (defined $more && $more eq "-"));

 $me->{Code} = $code;
 $me->{Resp} = [ @resp ];

 substr($code,0,1);
}


##
## RFC821 commands
##

sub not_supported {
 my $me = shift;
 $me->{Code} = 502;
 $me->{Resp} = [ "Not Supported\n" ];
 0;
}

sub HELO { 2 == shift->cmd("HELO",@_) } 		# HELO <SP> <domain>
sub MAIL { 2 == shift->cmd("MAIL", "FROM:<$_[0]>")  } 	# MAIL <SP> FROM:<reverse-path>
sub RCPT { 2 == shift->cmd("RCPT", "TO:<$_[0]>") } 	# RCPT <SP> TO:<forward-path>
sub DATA { 3 == shift->cmd("DATA") } 			# DATA
sub RSET { 2 == shift->cmd("RSET") } 			# RSET
sub SEND { 2 == shift->cmd("SEND", "FROM:<$_[0]>") } 	# SEND <SP> FROM:<reverse-path>
sub SOML { 2 == shift->cmd("SOML", "FROM:<$_[0]>") } 	# SOML <SP> FROM:<reverse-path>
sub SAML { 2 == shift->cmd("SAML", "FROM:<$_[0]>") } 	# SAML <SP> FROM:<reverse-path>
sub VRFY { 2 == shift->cmd("VRFY", shift) } 		# VRFY <SP> <string>
sub EXPN { 2 == shift->cmd("EXPN", shift) } 		# EXPN <SP> <string>
sub HELP { 2 == shift->cmd("HELP", @_) } 		# HELP [<SP> <string>]
sub NOOP { 2 == shift->cmd("NOOP") } 			# NOOP
sub QUIT { 2 == shift->cmd("QUIT") } 			# QUIT
sub TURN { shift->not_supported; } 			# TURN

=back

=head2 AUTHOR

Graham Barr <Graham.Barr@tiuk.ti.com>

=head2 REVISION

$Revision: 1.6 $

=head2 COPYRIGHT

Copyright (c) 1995 Graham Barr. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut

1;

