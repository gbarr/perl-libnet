# Net::SMTP.pm
#
# Copyright (c) 1995 Graham Barr <Graham.Barr@tiuk.ti.com>. All rights
# reserved. This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::SMTP;

=head1 NAME

Net::SMTP - Simple Mail transfer Protocol Client

=head1 SYNOPSIS

 use Net::SMTP;

 # Constructors
 $smtp = Net::SMTP->new('mailhost');
 $smtp = Net::SMTP->new('mailhost', Timeout => 60);

=head1 DESCRIPTION

This module implements a client interface to the SMTP protocol, enabling
a perl5 application to talk to SMTP servers. This documentation assumes
that you are familiar with the SMTP protocol described in RFC821.

A new Net::SMTP object must be created with the I<new> method. Once
this has been done, all SMTP commands are accessed through this object.

=head1 EXAMPLES

This example prints the mail domain name of the SMTP server known as mailhost:

 #!/usr/local/bin/perl -w

 use Net::SMTP;

 $smtp = Net::SMTP->new('mailhost');

 print $smtp->domain,"\n";

 $smtp->quit;

This example sends a small message to the postmaster at the SMTP server
known as mailhost:

 #!/usr/local/bin/perl -w

 use Net::SMTP;

 $smtp = Net::SMTP->new('mailhost');

 $smtp->mail($ENV{USER});

 $smtp->to('postmaster');

 $smtp->data();

 $smtp->datasend("To: postmaster\n");
 $smtp->datasend("\n");
 $smtp->datasend("A simple test message\n");

 $smtp->dataend();

 $smtp->quit;

=cut

require 5.001;
use Socket 1.3;
use Carp;

$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);
sub Version { $VERSION }

BEGIN
{
 if(eval { require Symbol })
  {
   import Symbol;
  }
 else
  {
   # Compatability :!?
   $socksym = "smtp00000";
   *gensym = sub {\*{"Net::SMTP::" . $socksym++}}
  }
}

=head1 CONSTRUCTOR

=head2 new ( $hostname, [ %options ] )

This is the constructor for a new Net::SMTP object. C<hostname> is the
name of the remote host to which a SMTP connection is required.

Possible options are:

=over 4

=item Hello

SMTP requires that you identify yourself. This option
specifies a string to pass as your mail domain. If not
given a guess will be taken.

=item Timeout

Maximum time, in seconds, to wait for a response from the
SMTP server (default: 120)

=item Debug

Enable debugging information

=back

Example:


 $smtp = Net::SMTP->new('mailhost',
                        Hello => 'my.mail.domain'
                       );


=cut

sub new
{
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

 my $me = $sock;


 @{*$me} = ();					# Last response text

 %{*$me} = (
            Code    => 0, 			# Last response code
            Timeout => $arg{Timeout} || 120, 	# Timeout value
            Debug   => $arg{Debug} || 0 	# Output debug information
           );

 bless $me, $pkg;

 select((select($me), $| = 1)[$[]);

 unless($me->response() == 2)
  {
   close($me);
   return undef;
  }

 (${*$me}{Domain}) = $me->message =~ /\A\s*(\S+)/;

 $me->hello($arg{Hello} || "");

 $me;
}

##
## User interface methods
##

=head1 METHODS

=head2 debug ( [ $level ] )

Turn the printing of debug information on/off for this object. If no
argument is given then the current state is returned. Otherwise the
state is changed to C<level> and the previous state returned.

=cut

sub debug
{
 my $me = shift;
 my $debug = ${*$me}{Debug};

 ${*$me}{Debug} = 0 + shift
	if(@_);

 $debug;
}

=head2 domain

Returns the domain that the remote SMTP server identified itself as during
connection.

=cut

sub domain
{
 my $me = shift;

 return ${*$me}{Domain} || undef;
}

=head2 hello ( $domain )

Tell the remoter server the mail domain which you are in using the HELO
command. Returns I<true> if command succeeded.

=cut

sub hello
{
 my $me = shift;
 my $domain = shift ||
	      eval {
		    require Net::Domain;
		    Net::Domain::hostdomain();
		   };
 my $ok = $me->HELO($domain || "");
 my $remote = undef;

 ($remote) = $me->message =~ /\A(\S+)/ if($ok);

 return $remote;
}

=head2 mail ( $address )

=head2 send ( $address )

=head2 send_or_mail ( $address )

=head2 send_and_mail ( $address )

Send the appropriate command to the server MAIL, SEND, SOML or SAML.
Returns I<true> if command succeeded.

=cut

sub mail	  { shift->MAIL(shift || "") }
sub send	  { shift->SEND(shift || "") }
sub send_or_mail  { shift->SOML(shift || "") }
sub send_and_mail { shift->SAML(shift || "") }

=head2 reset

Send the RSET command to the server. Returns I<true> if command
succeeded.

=cut

sub reset
{
 my $me = shift;

 $me->dataend()
	if(exists ${*$me}{LASTch});

 $me->RSET();
}

=head2 recipient ( $address [, $address [ ...]] )

Send a RCPT command to the server for each address given. Returns I<true>
upon success or I<false> upon encountering a failure.

=cut

sub recipient
{
 my $smtp = shift;
 my $ok = 1;

 while($ok && scalar(@_))
  {
   $ok = $smtp->RCPT(shift);
  }
 return $ok;
}

=head2 to

A synonym for recipient

=cut

*to = \&recipient;

=head2 data ( [ @data ] )

Send a DATA command to the server. If C<@data> is not empty then its
contents are sent as the data, followed by the C<".\r\n"> termination string.
If C<@data> is empty, or not given, then data must be sent using datasend and
terminated with a call to dataend. Returns I<true> if command succeeded.

B<WARNING>: Calling data with an empty list, or no arguments, will cause
all subsequent commands to be entered as data until dataend is called. If it
is intended that an empty list sends an empty message then call as

 $smtp->data( @data, "");

which will not alter the contents on the message but will ensure that the
termination string is sent.

=cut

sub data
{
 my $me = shift;
 my $ok = $me->DATA();

 ${*$me}{LASTch} = " ";

 return $ok
	unless($ok && @_);

 $me->datasend(@_);

 $me->dataend;
}

=head2 datasend ( @data )

Sends contents of C<@data> to the server.
Returns I<true> if all the data was sucessfully sent.

=cut

sub datasend
{
 my $me = shift;

 return 0 
   unless(exists ${*$me}{LASTch} || $me->data());

 my $line = ${*$me}{LASTch} . join("" ,@_);

 print STDERR substr($line,1)
	if($me->debug);

 $line =~ s/\n\./\n../sgo;
 $line =~ s/(?!\r)\n/\r\n/sgo;
 
 ${*$me} = substr($line,-1);
 
 my $len = length($line) - 1;
 
 return $len < 1 ||
	syswrite($me, $line, $len, 1) == $len;
}

=head2 dataend

Terminate the sending of data by sending the C<".\r\n"> termination string.
Returns I<true> if the server accepts the data.

=cut

sub dataend
{
 my $me = shift;

 return 0
	unless(exists ${*$me}{LASTch});

 if(${*$me}{LASTch} eq "\r")
  {
   syswrite($me,"\n",1);
  }
 elsif(${*$me}{LASTch} ne "\n")
  {
   syswrite($me,"\r\n",2);
  }

 syswrite($me,".\r\n",3);

 delete ${*$me}{LASTch};

 2 == $me->response();
}

=head2 expand ( $address )

Send the EXPN command to the server. Returns an array of the lines
returned by the server.

=cut

sub expand
{
 my $me = shift;

 my @r = $me->EXPN(@_)  ? @{*$me}
			: ();

 return @r;
}

=head2 verify ( $address )

Send the VRFY command to the server. Returns I<true> upon success.

=cut

sub verify { shift->VRFY(@_) }

=head2 help ( [ $subject ] )

Request help text from the server. Returns the text or undef upon failure

=cut

sub help
{
 my $me = shift;

 return $me->HELP(@_) ? $me->message
		      : undef;
}

=head2 quit

Send the QUIT command to the remote SMTP server and close the socket connection.

=cut

sub quit
{
 my $me = shift;

 return undef
	unless($me->QUIT);

 close($me);

 return 1;
}


##
## Communication methods
##

=head2 timeout ( $timeout )

Set the timeout use for communications. Returns the previous value.

=cut

sub timeout
{
 my $me = shift;
 my $timeout = ${*$me}{Timeout};

 ${*$me}{Timeout} = 0 + shift if(@_);

 $timeout;
}

=head2 message

Returns the message text from the last responce that the server gave.

=cut

sub message
{
 my $me = shift;
 join("\n", @{*$me});
}

=head2 code

Returns the last responce code from the server.

=cut

sub code
{
 my $me = shift;
 return ${*$me}{Code} || 0;
}

=head2 ok

Returns I<true> if the last responce code was not an error code.

=cut

sub ok
{
 my $me = shift;
 my $code = ${*$me}{Code} || 0;

 0 < $code && $code < 400;
}

##
## Private methods
##

sub cmd
{
 my $me = shift;

 croak "Cannot send commands while sending data"
	if(exists ${*$me}{LASTch});

 if(scalar(@_)) {
  my $cmd = join(" ", @_);

  syswrite($me,$cmd . "\r\n",2 + length($cmd));

  print STDERR "$me>> $cmd\n"
	if($me->debug);
 }

 $me->response();
}

sub response
{
 my $me = shift;
 my $timeout = ${*$me}{Timeout};
 my($code,@resp,$rin,$rout,$partial,@buf,$buf,$more);

 $rin = '';
 vec($rin,fileno($me),1) = 1;
 $more = 0;
 @resp = ();
 $partial = '';
 $buf = "";

 do
  {
   if (($timeout==0) || select($rout=$rin, undef, undef, $timeout))
    {
     unless(sysread($me, $buf, 1024))
      {
       carp "Unexpected EOF on command channel";
       return undef;
      }

     substr($buf,0,0) = $partial;    ## prepend from last sysread

     @buf = split(/\r?\n/, $buf);  ## break into lines

     $partial = (substr($buf, -1, 1) eq "\n") ? ''
					      : pop(@buf);

     foreach $cmd (@buf)
      {
       print STDERR "$me<< $cmd\n"
		if($me->debug);

       ($code,$more) = ($1,$2)
		if $cmd =~ /^(\d\d\d)(.)/;
       push(@resp,$');
      }
    }
   else
    {
     carp "$me: Timeout" if($me->debug);
     return undef;
    }
  }
 while(length($partial) || (defined $more && $more eq "-"));

 ${*$me}{Code} = $code;
 @{*$me} = @resp;

 substr($code,0,1);
}

##
## RFC821 commands
##

sub not_supported
{
 my $me = shift;

 ${*$me}{Code} = 502;
 @{*$me} = ( "Not Supported\n" );

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

=head2 AUTHOR

Graham Barr <Graham.Barr@tiuk.ti.com>

=head2 REVISION

$Revision: 1.7 $

=head2 COPYRIGHT

Copyright (c) 1995 Graham Barr. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut

1;

