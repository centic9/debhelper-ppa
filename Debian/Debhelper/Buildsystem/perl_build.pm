# A build system class for handling Perl Build based projects.
#
# Copyright: © 2008-2009 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::perl_build;

use strict;
use base 'Debian::Debhelper::Buildsystem';

sub DESCRIPTION {
	"Perl Module::Build (Build.PL)"
}

sub check_auto_buildable {
	my ($this, $step) = @_;

	# Handles everything
	my $ret = -e $this->get_sourcepath("Build.PL");
	if ($step ne "configure") {
		$ret &&= -e $this->get_sourcepath("Build");
	}
	return $ret ? 1 : 0;
}

sub do_perl {
	my $this=shift;
	$ENV{MODULEBUILDRC} = "/dev/null";
	$this->doit_in_sourcedir("perl", @_);
}

sub new {
	my $class=shift;
	my $this= $class->SUPER::new(@_);
	$this->enforce_in_source_building();
	return $this;
}

sub configure {
	my $this=shift;
	$ENV{PERL_MM_USE_DEFAULT}=1;
	$this->do_perl("Build.PL", "installdirs=vendor", @_);
}

sub build {
	my $this=shift;
	$this->do_perl("Build", @_);
}

sub test {
	my $this=shift;
	$this->do_perl("Build", "test", @_);
}

sub install {
	my $this=shift;
	my $destdir=shift;
	$this->do_perl("Build", "install", "destdir=$destdir", "create_packlist=0", @_);
}

sub clean {
	my $this=shift;
	if (-e $this->get_sourcepath("Build")) {
		$this->do_perl("Build", "--allow_mb_mismatch", 1, "distclean", @_);
	}
}

1
