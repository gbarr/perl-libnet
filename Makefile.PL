# This -*- perl -*- script makes the Makefile
# $Id: Makefile.PL,v 1.5 1997/02/05 22:23:03 gbarr Exp $

#--- Distribution section ---

$NAME     = 'Net';
$DISTNAME = "libnet";
$VERSION  = "1.06";

BEGIN { require 5.002 }

use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);

#--- MY package

sub MY::libscan
{
 my($self,$path) = @_;

 return '' 
	if($path =~ m:/(RCS|CVS|SCCS)/: ||
	   $path =~ m:[~%]$: ||
	   $path =~ m:\.(orig|rej|nfs)$:
	  );
 
 $path;
}

#--- Installation check

sub chk_version
{
 my($pkg,$wanted,$msg) = @_;

 local($|) = 1;
 print "Checking for $pkg...";

 eval { my $p; ($p = $pkg . ".pm") =~ s#::#/#g; require $p; };

 my $vstr = ${"${pkg}::VERSION"} ? "found v" . ${"${pkg}::VERSION"}
				 : "not found";
 my $vnum = ${"${pkg}::VERSION"} || 0;

 print $vnum >= $wanted ? "ok\n" : " " . $vstr . "\n";

 $vnum >= $wanted;
}

sub MY::post_initialize
{
 my ($self) = @_;

#--- Create Net::Config

my $config_pm = "Net/Config.pm";
my $libnet_cfg = "libnet.cfg";

# Use %INC and ExtUtils::MakeMaker to determine how this machine
# maps package names to path names

foreach (keys %INC) {
 last if ($config_pm = $_) =~ s/^ExtUtils(.)MakeMaker/Net${1}Config/;
}

system(($^O eq 'VMS' ? 'mcr ': ()),$^X, 'Configure')
	unless -f $libnet_cfg;

 $self->{PM}->{$libnet_cfg} = $self->catfile('$(INST_ARCHLIBDIR)',$config_pm);

 "";
}

#--- Check for Socket

chk_version(Socket => '1.30') or
    warn  "\n"
	. "*** For Net::Cmd to work you require version 1.30, or later, of\n"
	. "    Socket.pm from CPAN/modules/by-module/Socket/Socket-x.x.tar.gz\n\n";

chk_version(IO::Socket => '1.05') or
    warn  "\n"
	. "*** For Net::Cmd to work you require version 1.05, or later, of\n"
	. "    IO/Socket.pm from CPAN/modules/by-module/IO/IO-x.x.tar.gz\n\n";

#--- Write the Makefile

my @clean = qw(*% *.html *.b[ac]k *.old *.orig *.rej);

push @clean, map { "*/$_" } @clean;

WriteMakefile(
	VERSION   => $VERSION,
	DISTNAME  => $DISTNAME,
	NAME      => $NAME,

	'dist'    => {COMPRESS => 'gzip -9f',
		      SUFFIX   => '.gz', 
		      DIST_DEFAULT => 'all tardist',
		     },
 
	'clean'   => {FILES => join(" ", @clean,  )},
	'realclean'   => {FILES => $config_pm},
	PREREQ_PM => {
			Socket => 1.3,
			IO::Socket => 1.05
		    },
);
