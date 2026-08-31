====================================
reStructuredText directive showcase
====================================

.. |project| replace:: Driftwood
.. |release| replace:: 2.4.1

A single document exercising the constructs a reStructuredText parser is
expected to handle. Nothing here describes a real product; |project| is
invented for the purpose.

.. contents:: On this page
   :depth: 3

Titles and sections
===================

Subsection
----------

Sub-subsection
~~~~~~~~~~~~~~

Sub-sub-subsection
^^^^^^^^^^^^^^^^^^

The underline character determines the level, and the order in which characters
first appear in a document fixes their meaning for that document.

Inline markup
=============

*Emphasis*, **strong emphasis**, ``inline literal``, and a
`hyperlink reference`_ that resolves at the bottom of the page. Interpreted
text carries a role: :sup:`superscript`, :sub:`subscript`, :title:`a title`,
and :emphasis:`emphasis by role`.

Substitutions expand inline: this page documents |project| |release|.

Escaping works with a backslash, so \*this is not emphasised\* and
\``this is not a literal``.

.. _hyperlink reference: https://example.invalid/driftwood

Lists
=====

Bullet list
-----------

- First item.
- Second item, which runs onto a second line and stays part of the same item
  because the continuation is indented to match.
- Third item.

  - Nested item.
  - Another nested item.

    - Deeper still.

Enumerated list
---------------

1. Explicitly numbered.
2. Also explicitly numbered.

   a. Lettered sub-item.
   b. Another one.

      i. Roman sub-sub-item.
      ii. And another.

#. Auto-numbered, continuing the sequence.
#. And again.

Definition list
---------------

archive
    A single file holding many stored objects and the index that names them.

object
    A byte stream stored under the digest of its own contents.

    An object has no name. Names live in the index, and several names may point
    at one object.

digest
    Thirty-two bytes identifying an object uniquely.

Field list
----------

:Author: Sample Assets
:Version: |release|
:Status: Draft
:Copyright: MIT
:Tested against: docutils 0.21, sphinx 7.x

Option list
-----------

-v, --verbose       Print one line per file processed.
-q, --quiet         Suppress everything except errors.
--exclude=PATTERN   Skip paths matching PATTERN. Repeatable.
--dry-run           Report what would happen and change nothing.

Literal blocks
==============

A literal block introduced by a double colon::

    driftwood pack ./photos --into photos.dw
      scanned 4,812 files
      stored  4,166 objects

A code block with a language, for a highlighter to colour:

.. code-block:: python
   :linenos:
   :emphasize-lines: 4

   def store_all(paths, store):
       digests = {}
       for path in paths:
           with open(path, "rb") as handle:
               digests[path] = store.put(handle)
       return digests

.. code-block:: console

   $ driftwood verify photos.dw --fast
   4,166 objects checked, 0 mismatches

A parsed literal, where inline markup still works:

.. parsed-literal::

   driftwood pack *SOURCE* --into *ARCHIVE*
   driftwood unpack *ARCHIVE* *PATTERN* --to *DIR*

Block quote
===========

    A sample that only exercises the constructs an author happens to like is
    not a sample of the format. It is a sample of the author.

    -- from the repository's own contributing guide

Line block
==========

| Lines that keep their breaks
|   and their indentation
| are written as a line block,
| which is how verse survives a parser.

Tables
======

Simple table
------------

=====  =====  ======
  A      B    A or B
=====  =====  ======
False  False  False
True   False  True
False  True   True
True   True   True
=====  =====  ======

Grid table
----------

+----------------+---------------+----------------------------+
| Command        | Reads archive | Writes archive             |
+================+===============+============================+
| ``pack``       | no            | yes                        |
+----------------+---------------+----------------------------+
| ``unpack``     | yes           | no                         |
+----------------+---------------+----------------------------+
| ``gc``         | yes           | yes, in place              |
+----------------+---------------+----------------------------+

List table
----------

.. list-table:: Exit codes
   :header-rows: 1
   :stub-columns: 1
   :widths: 10 40

   * - Code
     - Meaning
   * - 0
     - Success
   * - 1
     - Usage error
   * - 2
     - Archive not found or unreadable

Admonitions
===========

.. note::
   Notes carry information the reader can act on later.

.. tip::
   Pass ``--dry-run`` first. It costs nothing and it has saved everybody at
   least once.

.. important::
   The index is rewritten in place during ``gc``. Take a copy first.

.. warning::
   Extended attributes are not preserved.

.. caution::
   A short digest is for display only.

.. danger::
   ``gc --force`` drops unreferenced objects without confirmation.

.. attention::
   Version 3.0 removes ``put_bytes``.

.. error::
   Verification failed. Re-run without ``--fast`` to locate the object.

.. admonition:: A custom admonition

   Any title may be given to a generic admonition, which is how a project
   invents its own categories without extending the parser.

Images and figures
==================

.. image:: ../../images/icons/icon-cloud-download-512x512.png
   :alt: A cloud with a downward arrow
   :width: 96px

.. figure:: ../../images/icons/icon-shield-sparkle-512x512.png
   :alt: A shield with a sparkle
   :width: 96px
   :align: left

   A figure is an image with a caption.

   And, optionally, a legend below the caption, set in the same block.

Footnotes and citations
=======================

A numbered footnote [1]_, an auto-numbered one [#]_, an auto-symbol one [*]_,
and a citation [Okonkwo2026]_.

.. [1] Numbered footnotes are matched by their label.
.. [#] Auto-numbered footnotes are matched in order of appearance.
.. [*] Auto-symbol footnotes cycle through a fixed sequence of marks.
.. [Okonkwo2026] T. Okonkwo, *Counting doors, counting people*, Journal of
   Invented Methods, 2026.

Comments and metadata
=====================

.. This is a comment. It does not appear in the rendered output, and it is the
   right place for a note to the next editor of the file.

.. meta::
   :description: A reStructuredText document exercising common directives.
   :keywords: rst, docutils, sample

Transitions
===========

A transition is a horizontal break between parts of a document:

----

And the text continues on the other side of it.

Raw output
==========

.. raw:: html

   <p><em>This paragraph is passed through to HTML output only.</em></p>

Directives that produce nothing visible
=======================================

.. sectnum::
   :depth: 2

.. default-role:: literal

Both change how the rest of the document is processed rather than adding
content to it.
