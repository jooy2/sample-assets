==============
Driftwood CLI
==============

.. image:: https://img.shields.io/badge/license-MIT-blue.svg
   :alt: MIT licensed

.. image:: https://img.shields.io/badge/python-3.9%2B-blue.svg
   :alt: Python 3.9 and above

**Driftwood** turns a directory of loose files into a single, addressable
archive, and back again, without ever holding more than one file in memory.

.. note::

   Driftwood is a fictional project written as a sample document. The commands
   below are illustrative; there is no package to install.

.. contents:: Table of contents
   :depth: 2
   :local:

Why
===

Archiving tools optimise for the archive. Driftwood optimises for the *next*
archive: the one you make tomorrow from a directory that is mostly the same.
It stores files by content hash, so a re-run copies only what actually changed.

Features
========

- **Content-addressed storage.** Identical files are stored once, however many
  paths point at them.
- **Streaming.** Memory use is bounded by the largest single chunk, not by the
  largest file.
- **Resumable.** An interrupted run picks up where it stopped.
- **No daemon.** Driftwood is a command, not a service.

Installation
============

From PyPI:

.. code-block:: console

   $ pip install driftwood

From source:

.. code-block:: console

   $ git clone https://example.invalid/driftwood.git
   $ cd driftwood
   $ pip install -e .

Quick start
===========

Create an archive from a directory:

.. code-block:: console

   $ driftwood pack ./photos --into photos.dw
   scanned 4,812 files (3.2 GiB)
   stored  4,166 objects (2.7 GiB, 16% deduplicated)
   wrote   photos.dw

List what is inside without unpacking:

.. code-block:: console

   $ driftwood list photos.dw --limit 3
   2027-04-11  1.2 MiB  photos/2027/april/harbour-01.jpg
   2027-04-11  1.1 MiB  photos/2027/april/harbour-02.jpg
   2027-04-12  982 KiB  photos/2027/april/kestrel-point.jpg

Extract a single path:

.. code-block:: console

   $ driftwood unpack photos.dw 'photos/2027/april/*' --to ./restored

Commands
========

.. list-table::
   :header-rows: 1
   :widths: 18 52 30

   * - Command
     - Does
     - Common option
   * - ``pack``
     - Build an archive from a directory
     - ``--exclude PATTERN``
   * - ``unpack``
     - Restore paths from an archive
     - ``--to DIR``
   * - ``list``
     - Print the archive index
     - ``--limit N``
   * - ``verify``
     - Re-hash every object and report mismatches
     - ``--fast``
   * - ``gc``
     - Drop objects no path refers to
     - ``--dry-run``

Configuration
=============

Driftwood reads ``driftwood.toml`` from the working directory, then from
``~/.config/driftwood/``. Command-line flags override both.

.. code-block:: toml

   [pack]
   chunk-size = "4MiB"
   exclude = [".DS_Store", "*.tmp", "node_modules/"]

   [verify]
   parallelism = 4

Exit codes
==========

=====  =========================================
Code   Meaning
=====  =========================================
0      Success
1      Usage error
2      Archive not found or unreadable
3      Verification failed
4      Interrupted; archive left resumable
=====  =========================================

Limitations
===========

.. warning::

   Driftwood does not preserve extended attributes, resource forks, or ACLs.
   If those matter to you, this is the wrong tool.

- Hard links are stored as separate paths pointing at one object, which is
  correct on restore but loses the link relationship.
- Archives are not encrypted. Encrypt the archive file itself if you need that.
- The index is read fully into memory on ``list``, which is a problem past
  roughly ten million paths.

Contributing
============

See ``CONTRIBUTING.rst``. In short: one change per pull request, tests for
anything that touches the object store, and no new dependencies without a note
saying why the standard library will not do.

License
=======

MIT. See ``LICENSE``.
