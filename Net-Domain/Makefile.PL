# This -*- perl -*- script makes the Makefile
# $Id: Makefile.PL,v 1.4 1995/11/16 11:57:04 gbarr Exp $

use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);

sub initialize {
 local($_);

 my $manifest = maniread();

 $Version = eval { require "./Domain.pm"; Net::Domain->Version; } || "0.00";

 my %pl_files = ();
 my @exe_files = ();

 foreach (keys %$manifest) {
  $pl_files{$_} = $1 if(/(.*)\.PL\Z/ && !/^Makefile.PL$/);
  push(@exe_files,$_) if(m#\bbin/# && !m#demo#);
 }

 my $hash = {
	VERSION   => $Version,
	NAME      => "Net::Domain",
	SKIP      => [qw(static dynamic)],
	PL_FILES  => \%pl_files,
	EXE_FILES => \@exe_files,

	'dist'    => {COMPRESS => 'gzip -9f',
		      SUFFIX   => 'gz', 
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

