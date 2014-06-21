#!perl

use 5.008001;

use strict;
use warnings;

use blib;
use Getopt::Long;
use Net::SMTP;

=head1 NAME

    smtp.self - mail a message via smtp

=head1 DESCRIPTION

C<smtp.self> will attempt to send a message to a given user

=head1 OPTIONS

=over 4

=item -debug

Enabe the output of dubug information

=item -help

Display this help text and quit

=item -user USERNAME

Send the message to C<USERNAME>

=head1 EXAMPLE

    demos/smtp.self  -user foo.bar

    demos/smtp.self -debug -user Graham.Barr

=back

=cut

my $opt_debug = undef;
my $opt_user = undef;
my $opt_help = undef;
GetOptions(qw(debug user=s help));

exec("pod2text $0")
    if defined $opt_help;

Net::SMTP->debug(1) if $opt_debug;

my $smtp = Net::SMTP->new("mailhost");

my $user = $opt_user || $ENV{USER} || $ENV{LOGNAME};

$smtp->mail($user) && $smtp->to($user);
$smtp->reset;

if($smtp->mail($user) && $smtp->to($user))
 {
  $smtp->data();

  my @data;
  map { s/-USER-/$user/g } @data=<DATA>; ## no critic (ControlStructures::ProhibitMutatingListFunctions)

  $smtp->datasend(@data);
  $smtp->dataend;
 }
else
 {
  warn $smtp->message;
 }

$smtp->quit;

__DATA__
To: <-USER->
Subject: A test message

The message was sent directly via SMTP using Net::SMTP
.
The message was sent directly via SMTP using Net::SMTP
