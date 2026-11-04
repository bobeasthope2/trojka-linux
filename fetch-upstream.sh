#!/bin/sh
#
# Pull in the original Trojka source, as described by upstream.conf.
#
# This repository contains no upstream source code: only the Debian packaging
# and the patches that port the 1995 sources to modern Linux.  The original
# tarball is downloaded from the mirrors listed in upstream.conf and verified
# against the checksum there before anything else touches it.
#
set -eu

CONF=${CONF:-upstream.conf}
DISTDIR=${DISTDIR:-distfiles}

if [ ! -r "$CONF" ]; then
	echo "fetch-upstream: cannot read $CONF" >&2
	exit 1
fi

# shellcheck source=upstream.conf
. "./$CONF"

for v in DISTFILE UPSTREAM_VERSION SHA256 SIZE MIRRORS; do
	eval "val=\${$v:-}"
	if [ -z "$val" ]; then
		echo "fetch-upstream: $v is not set in $CONF" >&2
		exit 1
	fi
done

ORIG=trojka_${UPSTREAM_VERSION}.orig.tar.gz

verify() {
	[ -f "$1" ] || return 1
	[ "$(wc -c < "$1" | tr -d ' ')" = "$SIZE" ] || return 1
	[ "$(sha256sum < "$1" | cut -d' ' -f1)" = "$SHA256" ] || return 1
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

Every mirror in $CONF failed.  The file is the 1995 Unix distribution of
Trojka, also carried by the FreeBSD ports tree as games/trojka.  Put a copy
at $DISTDIR/$DISTFILE and re-run; it must match:

  SHA256 $SHA256
  SIZE   $SIZE

EOF
	exit 1
fi

# dpkg-source wants the upstream tarball under the Debian orig name.  The
# bytes are untouched, so the .dsc checksum still matches the one upstream
# and FreeBSD publish.
cp -f "$DISTDIR/$DISTFILE" "$DISTDIR/$ORIG"
echo "fetch-upstream: $DISTDIR/$ORIG ready"
