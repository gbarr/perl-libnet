# This -*- perl -*- script makes the Makefile
# $Id: Makefile.PL,v 1.3 1995/11/21 08:09:01 gbarr Exp $

use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);

sub check_installation {
 my %pkg = @_;
 my $abort = 0;
 my $pkg;

 print "Checking your installation ...\n";

 foreach $pkg (keys %pkg) 
  {
   { eval "package dummy; require $pkg"; }

   my $ins_ver;
   my($version,$must) = @{$pkg{$pkg}};
   $version = sprintf("%.02f",$version);

   $ins_ver = defined ${$pkg . "::VERSION"}
                ? sprintf("%.02f",${$pkg . "::VERSION"})
                : undef;

   printf " %s %s, ",$pkg, (defined $ins_ver ? "Found v" . $ins_ver
                                             : "NOT FOUND");

   $ins_ver = "0.00" unless(defined $ins_ver);

   if($ins_ver < $version)
    {
     $abort += $must;
     printf "%s v%s\n", $must ? "REQUIRE " : "Recommend ", $version;
    }
   else
    {
     print "OK\n";
    }
  }

 die "Abort\n" if $abort;

 print "Done.\n";
}

sub initialize {
 local($_);

 my $manifest = maniread();

 $Version = eval { require "./SMTP.pm"; Net::SMTP->Version; } || "0.00";

 check_installation(Socket => [1.3, 1]);

 my %pl_files = ();
 my @exe_files = ();

 foreach (keys %$manifest) {
  $pl_files{$_} = $1 if(/(.*)\.PL\Z/ && !/^Makefile.PL$/);
  push(@exe_files,$_) if(m#\bbin/# && !m#demo#);
 }

 my $hash = {
	VERSION   => $Version,
	NAME      => 'Net::SMTP',
	SKIP      => [qw(static dynamic)],
	PL_FILES  => \%pl_files,
	EXE_FILES => \@exe_files,

	'dist'    => {COMPRESS => 'gzip -9f',
		      SUFFIX   => 'gz', 
		      POSTOP   => 'mv $(DISTNAME)-$(VERSION).tar.gz ../',
		      DIST_DEFAULT => 'all tardist',
		      CI => 'ci -l'
		     },

	'linkext' => {LINKTYPE => '' },
	'clean'   => {FILES => '*% *.html *.bak *.old lib/*% lib/*/*% $(EXE_FILES)'},
 };

 $hash;
}

if ($ExtUtils::MakeMaker::Version < 4.17) {
 my $hash = initialize();
 WriteMakefile( %$hash ) ;
}
else {
 WriteMakefile( CONFIGURE => \&initialize ) ;
}


sub MY::test {
    q{
TEST_VERBOSE=0

test:
	$(FULLPERL) -I$(INST_LIB) -I$(PERL_ARCHLIB) -I$(PERL_LIB) -e 'use Test::Harness qw(&runtests $$verbose); $$verbose=$(TEST_VERBOSE); runtests @ARGV;' t/*.t

};
}

sub MY::libscan {
    return '' if m:/(RCS|CVS)/:;
    return '' if m/[~%]$/;
    return '' if m/\.(orig|rej)$/;
    $_;
}

