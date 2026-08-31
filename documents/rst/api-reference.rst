=================
API reference
=================

:module: ``driftwood.store``
:version: 2.4
:status: stable

This page documents the object store that sits underneath every Driftwood
command. It is a sample document for a fictional library; the signatures are
illustrative rather than executable.

.. contents::
   :local:
   :backlinks: none

Overview
========

The store is a content-addressed map from a 32-byte digest to a byte stream.
It knows nothing about paths, directories, or archives — those live one layer
up, in ``driftwood.index``.

.. code-block:: python

   from driftwood.store import Store

   with Store.open("photos.dw") as store:
       digest = store.put(open("harbour.jpg", "rb"))
       print(digest.hex())

Classes
=======

Store
-----

.. class:: Store(path, *, mode="r", chunk_size=4194304)

   An open handle onto a store file.

   :param path: Filesystem path to the store.
   :type path: str or os.PathLike
   :param mode: ``"r"`` to read, ``"w"`` to create, ``"a"`` to append.
   :type mode: str
   :param chunk_size: Bytes read per iteration. Must be a power of two between
                      64 KiB and 64 MiB.
   :type chunk_size: int
   :raises FileNotFoundError: if *path* does not exist and *mode* is ``"r"``.
   :raises ValueError: if *chunk_size* is out of range or not a power of two.

   .. classmethod:: open(path, **kwargs)

      Context-manager constructor. Equivalent to ``Store(path, **kwargs)``,
      but guarantees the handle is closed on exit even if an exception
      propagates.

   .. method:: put(fileobj)

      Read *fileobj* to exhaustion and store its contents.

      :param fileobj: Any object with a ``read(n)`` method returning bytes.
      :returns: The digest of the stored content.
      :rtype: bytes
      :raises StoreFullError: if the store has reached its configured limit.

      Storing content that is already present is a no-op and returns the
      existing digest. This makes ``put`` safe to call repeatedly.

   .. method:: get(digest)

      Return a readable stream over the stored content.

      :param digest: A 32-byte digest as returned by :meth:`put`.
      :type digest: bytes
      :rtype: typing.BinaryIO
      :raises KeyError: if no object with that digest is present.

   .. method:: contains(digest)

      :rtype: bool

      Cheap membership test. Does not read the object body.

   .. method:: verify(*, fast=False)

      Re-hash every object and compare against its recorded digest.

      :param fast: When true, hash only the first and last chunk of each
                   object. Catches truncation and header corruption, misses
                   corruption in the middle.
      :type fast: bool
      :returns: Digests that failed verification, in store order.
      :rtype: list[bytes]

   .. method:: close()

      Flush and release the handle. Called automatically by the context
      manager.

   .. attribute:: object_count

      Number of distinct objects in the store. Read-only.

   .. attribute:: byte_size

      Total size of the store file on disk, in bytes. Read-only.

Digest
------

.. class:: Digest(raw)

   A thin wrapper around 32 bytes that compares, hashes, and formats
   sensibly.

   .. method:: hex()

      :rtype: str

      Lowercase hexadecimal, 64 characters.

   .. method:: short()

      :rtype: str

      The first 12 hex characters, for display only. Never use a short digest
      as a key.

   .. classmethod:: from_hex(text)

      :raises ValueError: if *text* is not 64 hexadecimal characters.

Exceptions
==========

.. exception:: StoreError

   Base class for everything raised by this module.

.. exception:: StoreFullError

   Bases: :exc:`StoreError`

   Raised by :meth:`Store.put` when the store has reached the limit set by
   ``[store] max-size`` in the configuration file.

.. exception:: CorruptStoreError

   Bases: :exc:`StoreError`

   Raised on open when the store header does not parse. A store that fails
   :meth:`Store.verify` does *not* raise this; verification reports rather
   than raises.

Constants
=========

.. data:: DIGEST_SIZE

   ``32``. The length in bytes of every digest this module produces.

.. data:: MIN_CHUNK_SIZE
.. data:: MAX_CHUNK_SIZE

   ``65536`` and ``67108864`` respectively.

Thread safety
=============

.. warning::

   A :class:`Store` opened for writing is **not** thread-safe. A store opened
   for reading is safe to share across threads, provided no other process holds
   it open for writing at the same time.

Deprecations
============

.. deprecated:: 2.3
   ``Store.put_bytes(data)``. Use ``store.put(io.BytesIO(data))`` instead. The
   old method will be removed in 3.0.

.. versionadded:: 2.4
   :meth:`Store.verify` gained the *fast* parameter.

.. versionchanged:: 2.2
   :meth:`Store.get` now returns a stream rather than a ``bytes`` object.

See also
========

- ``driftwood.index`` — maps paths to digests.
- ``driftwood.pack`` — the command-line front end.
