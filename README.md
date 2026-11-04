# trojka-linux

Debian/Ubuntu packaging for **Trojka**, Maarten Los's ncurses falling-blocks
game from 1992, ported to build and run correctly on current Linux.

Blocks fall into a well. Line up three or more matching patterns horizontally
or diagonally and they collapse; three consecutive collapses score a *Trojka*
bonus. Ten difficulty levels.

```
     -SCORE-                #                    #       OOOO
                            #                    #
     -SPEED-                #                    #       ||||
        3                   #        $$$$        #
                            ######################
```

## This repository contains no upstream source code

Only the packaging and the patches. Two files describe the build:

- [`upstream.conf`](upstream.conf) — where the original code comes from:
  mirror list, filename, SHA256 and size.
- [`debian/patches/series`](debian/patches/series) — what gets applied on top.

`make` reads the first, downloads and verifies the original 1995 distfile,
then applies the second. The checksum and master site are the ones the FreeBSD
ports tree records for `games/trojka`, so a download can be cross-checked
against theirs.

This is deliberate. See [Licence](#licence) below.

## Build

```sh
sudo apt install build-essential debhelper libncurses-dev pkgconf curl
make            # fetch, verify, patch, build
sudo make install
```

`make` downloads `trojka.tar.gz` into `distfiles/`, refuses to proceed unless
the checksum matches, applies the patch series and produces
`build/trojka_1.0-1_amd64.deb`.

To build against a different mirror or a newer upstream drop, edit
`upstream.conf`; nothing else needs changing.

Other targets: `make fetch` (download only), `make check` (run the test suite),
`make clean`, `make distclean`.

If every mirror is down, drop a verified copy of `trojka.tar.gz` into
`distfiles/` yourself and re-run `make`.

## Play

```sh
trojka        # play
trojka -s     # show high scores
man 6 trojka  # full manual
```

| Key | Action |
| --- | --- |
| `4` `h` | move left |
| `6` `l` | move right |
| `2` `j` `0` `SPACE` | drop |
| `7` `k` | increase speed |
| `^L` | redraw screen |
| `q` | stop game / quit |

High scores live in `$HOME/.trojka.scores`. Needs a terminal of at least 80x24.

## The patches

`debian/patches/0001-port-to-c99-and-ncurses.patch` converts the K&R C sources
to prototyped C99 and fixes the defects that stop the game working on a modern
system:

- `ioctl(FIONREAD)` read into a `long`, picking up garbage high bytes on LP64.
- `fflush(stdin)` used as a keyboard flush, which is undefined behaviour.
- `usleep(1800000)` exceeded the permitted argument range.
- `selectspeed()` fell off the end of the function without returning a value.
- The score file was hardcoded to an unwritable path under `/usr/games/lib`;
  it is now per-user under `$HOME`, so no setgid binary is needed.
- "Cookie" messages were drawn on line 25, invisible on an 80x24 terminal.
- The `TAGGED` shadow matrix was not cleared between games.
- The link line ignored `LDFLAGS`, silently dropping distribution hardening
  flags.

Game logic, scoring, screen layout and timing are unchanged.

`0002-add-porting-notes-and-tests.patch` adds `PORTING-LINUX.md` and the test
harness; neither is upstream.

## Testing

`tests/ttytest.py` drives the game in a pseudo-terminal and renders each screen
with [pyte](https://github.com/selectel/pyte), so gameplay can be asserted
without a human at the keyboard:

```sh
python3 -m venv .venv && .venv/bin/pip install pyte
make check
```

Use `TERM=vt100`, not `xterm`: pyte does not implement ECMA-48 `REP`, so
ncurses' repeated-character optimisation makes runs of identical characters
render as a single character.

## Licence

Trojka is **not** open source. The upstream `COPYRIGHT`, shipped inside the
distfile, permits redistribution of the *unmodified* Unix sources, allows
modification only to fit the code to your own system, and then says:

> To keep the versions a bit up to date, please mail any modification or
> incompatibility to me and don't redestribute your modified code.

That is why this repository ships patches rather than a modified source tree —
the same approach FreeBSD has used for `games/trojka` for about thirty years.
Nothing here reproduces upstream's code; the patches and the packaging are
original work.

Building the package locally is squarely within what the licence permits.
**Do not upload the result to Debian, Ubuntu or any other general distribution
archive** without the copyright holder's permission.

The name *Trojka* and the game concept are copyright © 1989–1995 Maarten Los.
Patches and packaging © 2026 Bob Easthope.

## See also

- FreeBSD port: [`games/trojka`](https://www.freshports.org/games/trojka/)
- XTrojka, the X11 version by the same author (separate, more restrictive
  licence — non-commercial distribution only)
