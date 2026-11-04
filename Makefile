# Build a Debian/Ubuntu package of Trojka from the upstream 1995 distfile
# plus the patches in debian/patches.
#
#   make            fetch, patch and build the .deb
#   make install    install the built package
#   make fetch      download and verify the upstream distfile only
#   make check      run the pty test suite against the built binary
#   make clean      remove the build tree (keeps the downloaded distfile)
#   make distclean  also remove the downloaded distfile

PACKAGE  = trojka
VERSION  = 1.0
REVISION = 1

# Override to use a virtualenv that has pyte installed, e.g.
#   make check PYTHON=.venv/bin/python
PYTHON  ?= python3

DISTDIR  = distfiles
DISTFILE = $(DISTDIR)/trojka.tar.gz
ORIG     = $(DISTDIR)/$(PACKAGE)_$(VERSION).orig.tar.gz
BUILDDIR = build
SRCDIR   = $(BUILDDIR)/$(PACKAGE)-$(VERSION)
DEB      = $(BUILDDIR)/$(PACKAGE)_$(VERSION)-$(REVISION)_$(shell dpkg-architecture -qDEB_HOST_ARCH).deb

.PHONY: all fetch source package install check clean distclean

all: package

fetch: $(ORIG)

$(ORIG): distinfo fetch-upstream.sh
	./fetch-upstream.sh

# Unpack upstream, drop our debian/ directory in, and let dpkg-source apply
# the patch series.  Upstream unpacks as trojka/, so it is renamed to the
# directory name dpkg-source expects.
source: $(SRCDIR)/debian/rules

$(SRCDIR)/debian/rules: $(ORIG) $(wildcard debian/* debian/*/*)
	rm -rf $(SRCDIR)
	mkdir -p $(BUILDDIR)
	tar xzf $(DISTFILE) -C $(BUILDDIR)
	mv $(BUILDDIR)/trojka $(SRCDIR)
	cp -a debian $(SRCDIR)/debian
	cp -f $(ORIG) $(BUILDDIR)/
	@touch $@

package: source
	cd $(SRCDIR) && dpkg-buildpackage -us -uc
	@echo
	@echo "Built: $(DEB)"

install: package
	sudo apt-get install -y ./$(DEB)

# dpkg-buildpackage unapplies the patch series when it finishes, which removes
# tests/ from the source tree, so re-apply it before running the suite.
check: package
	@$(PYTHON) -c 'import pyte' 2>/dev/null || { \
	  echo "pyte missing. Run:"; \
	  echo "  python3 -m venv .venv && .venv/bin/pip install pyte"; \
	  echo "  make check PYTHON=.venv/bin/python"; exit 1; }
	cd $(SRCDIR) && dpkg-source --before-build . >/dev/null
	TERM=vt100 $(PYTHON) $(SRCDIR)/tests/ttytest.py \
	  $(SRCDIR)/tests/steps/steps5.txt -- $(SRCDIR)/trojka

clean:
	rm -rf $(BUILDDIR)

distclean: clean
	rm -rf $(DISTDIR)
