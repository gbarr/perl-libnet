use ExtUtils::MakeMaker;

$Version = "0.00a";

require "./History.pl" if(-f "./History.pl");

WriteMakefile(
	      VERSION   => $Version,
	      NAME  => 'Net::FTP',
	      SKIP      => [qw(static dynamic)],
	      'dist'    => {COMPRESS=> 'gzip -9f', SUFFIX=>'gz', 
			     POSTOP => 'mv $(DISTNAME)-$(VERSION).tar.gz ../'
			   },
	      'linkext' => {LINKTYPE => '' }, #not needed for MakeMakers > 5
	      'clean'   => {FILES => "*% *.html"}
             );

