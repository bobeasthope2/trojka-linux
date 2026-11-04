#!/bin/sh
#
# Fetch the upstream Trojka distfile and verify it against distinfo.
#
# This repository contains no upstream source code: only the Debian packaging
# and the patches that port the 1995 sources to modern Linux.  The original
# tarball is downloaded from the same mirrors the FreeBSD ports tree uses.
#
set -eu

DISTFILE=trojka.tar.gz
ORIG=trojka_1.0.orig.tar.gz
DISTDIR=${DISTDIR:-distfiles}

# MASTER_SITES, in preference order.  The funet.fi entry is the master site
# recorded in the FreeBSD port; distcache is FreeBSD's own mirror of it.
MIRRORS="
https://www.nic.funet.fi/pub/unix/games/${DISTFILE}
http://distcache.freebsd.org/ports-distfiles/${DISTFILE}
ftp://ftp.funet.fi/pub/unix/games/${DISTFILE}
"

want_sha=$(sed -n 's/^SHA256 (.*) = //p' distinfo)
want_size=$(sed -n 's/^SIZE (.*) = //p' distinfo)

if [ -z "$want_sha" ] || [ -z "$want_size" ]; then
	echo "fetch-upstream: cannot read checksums from distinfo" >&2
	exit 1
fi

verify() {
	[ -f "$1" ] || return 1
	[ "$(wc -c < "$1" | tr -d ' ')" = "$want_size" ] || return 1
	[ "$(sha256sum < "$1" | cut -d' ' -f1)" = "$want_sha" ] || return 1
	return 0
}

mkdir -p "$DISTDIR"

if verify "$DISTDIR/$DISTFILE"; then
	echo "fetch-upstream: $DISTDIR/$DISTFILE already present and verified"
else
	rm -f "$DISTDIR/$DISTFILE"
	for url in $MIRRORS; do
		echo "fetch-upstream: trying $url"
		if curl -fsSL --connect-timeout 20 --max-time 120 \
		        -o "$DISTDIR/$DISTFILE.part" "$url" 2>/dev/null; then
			mv "$DISTDIR/$DISTFILE.part" "$DISTDIR/$DISTFILE"
			if verify "$DISTDIR/$DISTFILE"; then
				echo "fetch-upstream: fetched and verified from $url"
				break
			fi
			echo "fetch-upstream: checksum mismatch from $url, discarding" >&2
			rm -f "$DISTDIR/$DISTFILE"
		fi
		rm -f "$DISTDIR/$DISTFILE.part"
	done
fi

if ! verify "$DISTDIR/$DISTFILE"; then
	cat >&2 <<EOF

fetch-upstream: could not obtain a verified $DISTFILE.

All mirrors failed.  The file is the 1995 Unix distribution of Trojka,
also carried by the FreeBSD ports tree as games/trojka.  Place a copy at
$DISTDIR/$DISTFILE and re-run; it must match:

  SHA256 $want_sha
  SIZE   $want_size

EOF
	exit 1
fi

# dpkg-source wants the upstream tarball under the Debian orig name.  The
# bytes are untouched, so the .dsc checksum still matches FreeBSD's distinfo.
cp -f "$DISTDIR/$DISTFILE" "$DISTDIR/$ORIG"
echo "fetch-upstream: $DISTDIR/$ORIG ready"
