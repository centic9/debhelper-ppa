PERL ?= perl
PO4A ?= po4a
POD2MAN ?= pod2man

# List of files of dh_* commands. Sorted for debhelper man page.
COMMANDS=$(shell find . -maxdepth 1 -type f -perm /100 -name "dh_*" -printf "%f\n" | grep -v '~$$' | LC_ALL=C sort)
MANPAGES=$(COMMANDS:=.1) dh.1

# Find deprecated commands by looking at their synopsis.
DEPRECATED=$(shell egrep -l '^dh_.* - .*deprecated' $(COMMANDS))

ifneq (,$(filter parallel=%,$(DEB_BUILD_OPTIONS)))
    TEST_JOBS = $(patsubst parallel=%,%,$(filter parallel=%,$(DEB_BUILD_OPTIONS)))
else
    TEST_JOBS = 1
endif

# Figure out the `current debhelper version.
VERSION=$(shell dpkg-parsechangelog -SVersion)

# This generates a list of synopses of debhelper commands, and substitutes
# it in to the #LIST# line on the man page fed to it on stdin. Must be passed
# parameters of all the executables or pod files to get the synopses from.
# For correct conversion of pod tags (like S< >) #LIST# must be substituted in
# the pod file and not in the troff file.
MAKEMANLIST=$(PERL) -e ' \
		undef $$/; \
		foreach (@ARGV) { \
		        open (IN, $$_) or die "$$_: $$!"; \
		        $$file=<IN>; \
		        close IN; \
		        if ($$file=~m/=head1 .*?\n\n(.*?) - (.*?)\n\n/s) { \
				my $$item="=item $$1(1)\n\n$$2\n\n"; \
				if (" $(DEPRECATED) " !~ / $$1 /) { \
			                $$list.=$$item; \
				} \
				else { \
			                $$list_deprecated.=$$item; \
				} \
		        } \
		} \
		END { \
			my $$recommended_compat = q{$(VERSION)}; \
			$$recommended_compat =~ s{^\d+\K(?:\D.*|\..*)?}{}; \
			while (<STDIN>) { \
				s/\#LIST\#/$$list/g; \
				s/\#LIST_DEPRECATED\#/$$list_deprecated/g; \
				s/\#RECOMMENDED_COMPAT\#/$$recommended_compat/g; \
				print; \
			}; \
		}'

PERLLIBDIR=$(shell $(PERL) -MConfig -e 'print $$Config{vendorlib}')/Debian/Debhelper

PREFIX=/usr

POD2MAN_FLAGS=--utf8 -c Debhelper -r "$(VERSION)"

ifneq ($(USE_NLS),no)
# l10n to be built is determined from .po files
LANGS?=$(notdir $(basename $(wildcard man/po4a/po/*.po)))
LANG_TARGETS = $(foreach L,$(LANGS),translated-$(L)-stamp)
else
LANGS=
LANG_TARGETS =
endif

build: $(LANG_TARGETS) version debhelper.7 debhelper-obsolete-compat.7 $(MANPAGES)


po4a-stamp:
	$(PO4A) --previous -L UTF-8 man/po4a/po4a.cfg
	touch $@

translated-%-stamp: po4a-stamp
	set -e; \
	lang=$* ; \
	dir=man/$$lang; \
	for file in $$dir/dh*.pod; do \
		prog=`basename $$file | sed 's/.pod//'`; \
		$(POD2MAN) $(POD2MAN_FLAGS) $$file $$prog.$$lang.1; \
	done; \
	if [ -e $$dir/debhelper.pod ]; then \
		cat $$dir/debhelper.pod | \
			$(MAKEMANLIST) `find $$dir -type f -maxdepth 1 -name "dh_*.pod" | LC_ALL=C sort` | \
			$(POD2MAN) $(POD2MAN_FLAGS) --name="debhelper" --section=7 > debhelper.$$lang.7; \
	fi; \
	if [ -e $$dir/debhelper-obsolete-compat.pod ]; then \
		$(POD2MAN) $(POD2MAN_FLAGS) --name="debhelper" --section=7 $$dir/debhelper-obsolete-compat.pod > debhelper-obsolete-compat.$$lang.7; \
	fi
	touch $@

version:
	printf "package Debian::Debhelper::Dh_Version;\n\$$version='$(VERSION)';\n1" > \
		lib/Debian/Debhelper/Dh_Version.pm

dh_%.1: dh_%
	$(POD2MAN) $(POD2MAN_FLAGS) $^ $@

dh.1: dh
	$(POD2MAN) $(POD2MAN_FLAGS) $^ $@

debhelper.7: debhelper.pod
	cat debhelper.pod | \
		$(MAKEMANLIST) $(COMMANDS) | \
		$(POD2MAN) $(POD2MAN_FLAGS) --name="debhelper" --section=7  > $@

debhelper-obsolete-compat.7: debhelper-obsolete-compat.pod
	$(POD2MAN) $(POD2MAN_FLAGS) --name="debhelper" --section=7 $^ > $@

clean:
	rm -f *-stamp *.1 *.7 lib/Debian/Debhelper/Dh_Version.pm
ifneq ($(USE_NLS),no)
	$(PO4A) --previous --rm-translations --rm-backups man/po4a/po4a.cfg
endif
	for lang in $(LANGS); do \
		if [ -e man/$$lang ]; then rmdir man/$$lang; fi; \
	done;

install:
	install -d $(DESTDIR)$(PREFIX)/bin \
		$(DESTDIR)$(PREFIX)/share/debhelper/autoscripts \
		$(DESTDIR)$(PERLLIBDIR)/Sequence \
		$(DESTDIR)$(PERLLIBDIR)/Buildsystem
	install dh $(COMMANDS) $(DESTDIR)$(PREFIX)/bin
	install -m 0644 autoscripts/* $(DESTDIR)$(PREFIX)/share/debhelper/autoscripts
	install -m 0644 lib/Debian/Debhelper/*.pm $(DESTDIR)$(PERLLIBDIR)
	[ "$(PREFIX)" = /usr ] || \
		sed -i '/$$prefix=/s@/usr@$(PREFIX)@g' $(DESTDIR)$(PERLLIBDIR)/Dh_Lib.pm
	install -m 0644 lib/Debian/Debhelper/Sequence/*.pm $(DESTDIR)$(PERLLIBDIR)/Sequence
	install -m 0644 lib/Debian/Debhelper/Buildsystem/*.pm $(DESTDIR)$(PERLLIBDIR)/Buildsystem

test: version
	MAKEFLAGS= HARNESS_OPTIONS=j$(TEST_JOBS) ./run perl -MTest::Harness -e 'runtests grep { ! /CVS/ && ! /\.svn/ && -f && -x && m/\.t$$/ } @ARGV' t/* t/*/*
