# This -*- perl -*- script makes the Makefile
# $Id: Makefile.PL,v 1.8 1996/03/28 08:03:48 gbarr Exp $

#--- Configuration section ---

%install_pgm = ();

#--- End User Configuration - You should not have to change anything below this line

$NAME     = 'Net::FTP';
$RELTYPE = "_2";

$lib_only = 0;

#--- End Configuration

use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);
use FileHandle;

#--- MY package

sub MY::libscan
{
 my($self,$path) = @_;

 return '' 
	if($path =~ m:/(RCS|CVS|SCCS)/: ||
	   $path =~ m:[~%]$: ||
	   $path =~ m:\.(orig|rej)$:
	  );
 
 $path;
}

#--- End MY package

sub doIt
{
 my $manifest = maniread();
 
 my %PL_FILES = ();
 my %EXE_FILES = ();
 my %macro = ();

 #--- Install what ?
 
 foreach (keys %$manifest) {
  $PL_FILES{$_} = $1 if(/(.*)\.PL\Z/ && !/^Makefile.PL$/);
 
  if(m#\bbin/# && !m#demo#) {
   my $f = $_;
 
   $f =~ s#\.PL$##;
 
   if(defined $install_pgm{$f} && $install_pgm{$f}) {
    $EXE_FILES{$f} = 1 if(-x $f || -f "$f.PL");
   }
  }
 }
 
 %EXE_FILES = () if($lib_only);
 
 #--- Dist. VERSION
 
 unless(defined $VERSION)
  {
   my($pm,$rcs);
   my $fh = new FileHandle;
  
   ($pm = $NAME . ".pm") =~ s,.*::,,;
   ($pm = $NAME . ".pm") =~ s,::,/,g unless(-f $pm);
   $pm = "lib/" . $pm unless(-f $pm);
  
   if($fh->open($pm))
    {
     while (<$fh>)
      {
       chomp;
       next unless /\$([\w:]*\bVERSION)\b.*=/;
       my $module_version_variable = $1;
       my($eval) = "$_;";
       eval $eval;
       die "Could not eval '$eval': $@" if $@;
       $VERSION = $ {$module_version_variable};
       last;
      }
     close $fh;
    }
  
   ($rcs = $pm) =~ s:([^/]+\.pm):RCS/$1,v:;
  
   # update VERSION when checked in
   $macro{CONFIGDEP} = $rcs
     if(-f $rcs);
  }
 
 $VERSION .= $RELTYPE
 	if(defined $RELTYPE);
 
 #--- Write the Makefile
 
 %hash = (
	VERSION   => $VERSION,
	NAME      => $NAME,
	PL_FILES  => \%PL_FILES,
	EXE_FILES => [ keys %EXE_FILES ],
 
	'linkext' => {LINKTYPE => '' },
	'dist'    => {COMPRESS => 'gzip -9f',
		      SUFFIX   => 'gz', 
		      POSTOP   => 'mv $(DISTNAME)-$(VERSION).tar.gz ../',
		      DIST_DEFAULT => 'all tardist',
		      CI => 'ci -l'
		     },
 
	'clean'   => {FILES => join(" ", qw(*% *.html *.bak *.old lib/*% lib/*/*%),values %PL_FILES)},
 );
 
 $hash{macro} = \%macro
 	if(%macro);
 
 $hash{DISTNAME} = $DISTNAME
 	if(defined $DISTNAME);
 
 WriteMakefile( %hash ) ;
 
}

#--- UNIVERSAL package

sub UNIVERSAL::require_version
{
 my($self, $wanted) = @_;
 my $pkg = ref $self || $self;
 my $version = ${"${pkg}::VERSION"} || "(undef)";

 die("$pkg $wanted required--this is only version $version")
		if $version < $wanted;

 $version;
}

#--- End UNIVERSAL package
#--- Installation check

sub require_version
{
 my($pkg,$version,$msg) = @_;

 $| = 1;
 print "Checking for $pkg...";

 eval " require $pkg; $pkg->require_version('$version') ";

 print $@ ? "failed\n" . $msg  : "ok\n";
}

#--- Check for Socket

require_version(
'Socket',
'1.30',
"
For Net::FTP to work you require the Socket distribution
version 1.30 or later.
"
);

#--- Write the Makefile

doIt();

