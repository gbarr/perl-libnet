#!/usr/local/bin/perl

BEGIN { unshift @INC, "./lib", "./blib" }
use Net::FTP;

sub test_gate {
 my $ftp = Net::FTP->new('gate.ti.com');
 my($user,$pswd) = @_;

 $ftp->login('anonymous@ftp.icnet.uk',"$ENV{USER}\@tiuk.ti.com");

# if($user && $pswd) {
#  $ftp->auth($user) || warn $ftp->message;
#  $ftp->resp($pswd) || warn $ftp->message;
# }
 $ftp->authorise($user,$pswd);
 print @{$ftp->lsl};

 $ftp->quit;
}

sub test_mosftp {
 my $ftp = Net::FTP->new('mosftp.tiuk.ti.com');

 $ftp->login(); # anonymous
 $ftp->chdir("pub");

 $file =  "MANIFEST";
 
 $file = $ftp->put_unique($file);

 print @{$ftp->ls};
 
# if(defined $file && defined($sock = $ftp->retr($file))) {
#  print <$sock>;
#  close $sock;
#  $ftp->response();
# }

 if(defined $file) {
  $ftp->get($file,\*STDOUT) || warn $ftp->message;
  $ftp->get($file) || warn $ftp->message;
  warn $ftp->message;
 }

 $ftp->quit;
}

sub test_passive {
 my $ftpf = Net::FTP->new('mosftp.tiuk.ti.com');
 my $ftpt = Net::FTP->new('mosftp.tiuk.ti.com');

# $ftpt->debug(0);

 $ftpf->login();
 $ftpt->login();

 $ftpf->chdir("pub");                                                   
 $ftpt->chdir("pub");                                                    

 $ftpf->put("MANIFEST","testfile");

 $ftpf->port($ftpt->pasv) || die $ftpt->message;

 $ftpf->retr("testfile"); # Non passive server first !!!
 $ftpt->stou("testfile");

 $file = $ftpt->pasv_wait($ftpf);

 print $ftpt->lsl(),"\n";
 warn $file;
 $ftpf->get($file,"OUTPUT");
 
 $ftpt->quit;
 $ftpf->quit;
}

sub test_solaris {
 my $ftp = Net::FTP->new("lum");
 $ftp->login("a909937","d5txba");
 print $ftp->lsl(),"\n";
 $ftp->get(".cshrc","cshrc");
 $ftp->quit();
}

#test_gate(@_);
#test_mosftp;
#test_passive;
test_solaris;
