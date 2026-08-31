=========
Changelog
=========

All notable changes to **Driftwood** are recorded here. The format follows
`Keep a Changelog`_, and the project follows `Semantic Versioning`_.

Driftwood is a fictional project; every entry below was written as a sample.

.. _Keep a Changelog: https://keepachangelog.com/en/1.1.0/
.. _Semantic Versioning: https://semver.org/spec/v2.0.0.html

.. contents::
   :local:
   :depth: 1

Unreleased
==========

Added
-----

- ``driftwood mount`` for read-only FUSE mounts of an archive. Linux and macOS
  only; behind the ``mount`` extra.
- ``--json`` on ``list`` and ``verify``, emitting one object per line.

Changed
-------

- ``gc`` now reports reclaimed bytes before asking for confirmation rather than
  after.

2.4.1 — 2027-08-19
==================

Fixed
-----

- ``verify --fast`` reported a mismatch for objects smaller than one chunk,
  because the first and last chunk were the same chunk and were hashed twice.
- The progress line no longer overwrites the last line of output when stdout is
  not a terminal.

2.4.0 — 2027-07-30
==================

Added
-----

- ``Store.verify()`` gained a *fast* parameter, hashing only the first and last
  chunk of each object. Roughly forty times quicker on large archives, and
  blind to corruption in the middle of an object.
- ``--exclude`` accepts a leading ``!`` to re-include a path an earlier pattern
  excluded.

Changed
-------

- The default chunk size rose from 1 MiB to 4 MiB. Archives written by older
  versions still read correctly; the size is recorded per object.
- ``list`` sorts by path rather than by insertion order. Pass ``--raw`` for the
  old behaviour.

Deprecated
----------

- ``Store.put_bytes(data)``. Use ``store.put(io.BytesIO(data))``. Removal is
  scheduled for 3.0.

2.3.2 — 2027-06-11
==================

Fixed
-----

- An interrupted ``pack`` left a lock file behind, so the resumed run refused to
  start. The lock is now released on ``SIGINT`` and ``SIGTERM``.
- Paths containing a newline were written to the index unescaped, which
  corrupted every path after them.

Security
--------

- Archive paths are now rejected if they escape the extraction root after
  normalisation. Previously a crafted archive could write outside ``--to``.
  Reported privately; no released archive is known to have exploited it.

2.3.0 — 2027-05-02
==================

Added
-----

- Resumable ``pack``. An interrupted run writes a journal beside the archive and
  picks up from the last completed object.
- ``driftwood gc --dry-run``.

Changed
-------

- ``Store.get()`` returns a stream rather than a ``bytes`` object. **Breaking
  for anyone who indexed the result**, though the release is a minor one because
  the method was documented as returning a file-like object from the start.

Removed
-------

- The ``--compat-1x`` flag, which had been a no-op since 2.0.

2.2.0 — 2027-03-14
==================

Added
-----

- Hard links are recorded as multiple paths pointing at one object.
- ``verify`` reports progress against object count rather than byte count, which
  is a worse estimate of time but a better one of work remaining.

Fixed
-----

- Memory use during ``pack`` grew with the number of files rather than staying
  bounded, because the index was accumulated in full before being written.

2.1.0 — 2027-02-01
==================

Added
-----

- Configuration file support: ``driftwood.toml`` in the working directory, then
  ``~/.config/driftwood/``.
- ``--parallelism`` on ``verify``.

2.0.0 — 2027-01-08
==================

Changed
-------

- **Breaking.** The archive format changed. 2.x cannot read a 1.x archive, and
  1.x cannot read a 2.x archive. Convert with ``driftwood-1x list`` piped into
  ``driftwood pack --from-stdin``.
- **Breaking.** Digests are 32 bytes rather than 20.

Removed
-------

- **Breaking.** ``driftwood append``. Use ``pack`` against an existing archive.

1.4.3 — 2026-11-20
==================

Fixed
-----

- The last release of the 1.x line. Fixes a crash when an archive contained
  exactly zero objects.

.. note::

   1.x is no longer maintained. Security fixes stopped on 2027-01-08.
