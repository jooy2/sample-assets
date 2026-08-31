# Text

Long-form prose and verse as plain text. One file, one piece of writing, no markup.

## What this folder is for

Everything here exists to be **read as text**: by a viewer, an editor, a diff tool, a
search index, a summariser, a text-to-speech engine, an encoding test, or a person.

That makes it different from the two folders it sits between:

| Folder                                | Holds                                       | The file is       |
| ------------------------------------- | ------------------------------------------- | ----------------- |
| [`datasets/txt/`](../datasets/txt)     | Log lines, word lists, fixtures             | **Data** to parse |
| `text/`                                | Stories, reports, essays, poems             | **Prose** to read |
| [`documents/`](../documents)           | The same kind of writing, but formatted     | A **document**    |

A `.txt` file that is really a table, a log, or a list belongs in `datasets/txt/`. A piece
of writing that needs headings, italics, or a page layout belongs in `documents/` as
Markdown, HTML, or something heavier. What is left — writing whose only structure is
paragraphs, line breaks, and blank lines — belongs here.

## Format

`.txt` only. UTF-8, LF line endings, no BOM.

- **Hard-wrapped at 78 columns or less.** These files are meant to be readable in a
  terminal and in a viewer that does not reflow. A tool that reflows one of these files
  has damaged it; a tool that leaves it alone has passed. That is a useful thing to be
  able to test.
- **Structure comes from whitespace**: a blank line between paragraphs, a run of blank
  lines between sections, indentation and centring for headings and verse. There is no
  markup, and adding some would make the file something else.
- **No trailing whitespace**, and one newline at the end.

## Naming

Lowercase `kebab-case`, with the **genre first** and the subject after:

```text
story-the-last-round.txt
essay-on-things-that-need-somebody.txt
report-annual-library-service.txt
poems-tide-tables.txt
```

Genres in use: `childrens-story`, `essay`, `folk-tale`, `food-writing`,
`interview-transcript`, `journal`, `lecture-notes`, `letter`, `manifesto`, `memoir`,
`nature-notes`, `news-feature`, `novel-chapter`, `obituary`, `play-scene`, `poems`,
`report`, `review`, `speech`, `story`, `travel-notes`.

A new genre gets a new prefix and a line in that list. The genre goes in the **name**,
not in a subfolder: the folder is flat, the same way `images/photos/` is flat, because a
piece of writing usually belongs to more than one genre and a folder forces a choice
that a name does not.

## Length

These are **long-form** samples, which is the reason the folder exists. A piece under
about 500 words is not doing the job; most here run to between 1,000 and 2,500.

Keep any single file under 200 KB. Nothing here is close.

## Contents

Every piece is invented, and each says so in a line at the foot of the file.

The fiction shares a geography on purpose — the Fenwick estuary, the town of Corrance,
the Halloway crossing, the Northwind Ferry Cooperative — so that several samples can be
handed to the same tool and compared. None of those places exists, and no person named in
any of these files is real.

Some pieces are written in the voice of a genre that reports facts: an obituary, a news
feature, a council report, a set of lecture notes. **The facts in them are invented too.**
Nothing here should be quoted, cited, or treated as a record of anything.

## Sources

Text written for this repository is covered by its [LICENSE](../LICENSE). A piece that
comes from somewhere else keeps its own license, and is listed here with its source,
author, and terms before it is added. Nothing has been added yet — and note that
out-of-copyright literature, however convenient, is not exempt from being listed.
