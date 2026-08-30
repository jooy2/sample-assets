# Markdown kitchen sink

A single file exercising the syntax a Markdown renderer is usually asked to handle:
CommonMark, plus the GitHub-flavoured extensions. Nothing here describes anything real.

## Headings

# Heading level 1
## Heading level 2
### Heading level 3
#### Heading level 4
##### Heading level 5
###### Heading level 6

Setext heading level 1
======================

Setext heading level 2
----------------------

## Inline formatting

Plain text, *emphasis*, _also emphasis_, **strong**, __also strong__,
***strong emphasis***, ~~strikethrough~~, `inline code`, and a backslash escape: \*not
emphasis\*.

A hard line break ends this line with two spaces,  
so this continues on a new line.

Inline HTML: text with <sub>subscript</sub>, <sup>superscript</sup>, and <kbd>Ctrl</kbd> +
<kbd>C</kbd>.

Entities: &copy; &amp; &lt;tag&gt; &mdash; &nbsp; &hellip;

## Links and images

An [inline link](https://example.com), an [inline link with a title](https://example.com
"Example title"), a [reference link][ref], a [collapsed reference][], a [shortcut
reference], and an autolink: <https://example.com>.

An image: ![A compass icon](../images/icons/icon-compass-navigation-512x512.png "Compass")

A linked image: [![Badge](https://example.com/badge.svg)](https://example.com)

[ref]: https://example.com/reference "Reference title"
[collapsed reference]: https://example.com/collapsed
[shortcut reference]: https://example.com/shortcut

## Lists

Unordered:

- First item
- Second item
  - Nested item
    - Deeper item
- Third item

* An asterisk bullet
+ A plus bullet

Ordered:

1. First
2. Second
   1. Nested first
   2. Nested second
3. Third

Starting at another number:

7. Seven
8. Eight

Loose list, with paragraphs:

- First paragraph of the item.

  Second paragraph of the same item.

- Another item.

Task list:

- [x] Completed task
- [ ] Incomplete task
- [ ] ~~Cancelled task~~

Definition-style list, as plain text:

Term
: A definition, which not every renderer supports.

## Block quotes

> A single-level quote.
>
> > A nested quote.
>
> - A list inside a quote
> - Second item

> **Note**
> An alert-style quote, rendered as a callout by some viewers.

## Code

Indented code block:

    function indented() {
      return true;
    }

Fenced block without a language:

```
plain fenced text
  with indentation preserved
```

Fenced block with a language:

```python
def fib(n: int) -> int:
    """Return the nth Fibonacci number."""
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a
```

```json
{
  "name": "kestrel",
  "version": "2.3.0",
  "private": false,
  "tasks": ["build", "test"]
}
```

A fence containing a fence, opened with four backticks:

````
```
nested fence
```
````

## Tables

| Left    | Centre  | Right |
| :------ | :-----: | ----: |
| a       |    b    |     1 |
| longer  |  cell   |    22 |
| `code`  | **bold** | 333  |

A table with a pipe in a cell:

| Expression | Meaning         |
| ---------- | --------------- |
| `a \| b`   | bitwise or      |
| `a || b`   | logical or      |

## Horizontal rules

---

***

___

## Footnotes

A statement needing a source.[^1] Another one.[^note]

[^1]: The first footnote.
[^note]: A named footnote, with a second paragraph.

    Indented to stay part of the footnote.

## HTML block

<details>
<summary>A collapsed section</summary>

Hidden content, including a list:

- one
- two

</details>

<table>
  <tr><th>Raw</th><th>HTML</th></tr>
  <tr><td>table</td><td>cell</td></tr>
</table>

## Edge cases

A line ending in a backslash for a hard break:\
this line follows it.

Unicode: naïve café résumé — 안녕하세요 — こんにちは — Здравствуйте — مرحبا — 😀 🧪 ✅

An emoji shortcode, if supported: :sparkles:

A URL that should not autolink without brackets: https://example.com/plain

Trailing whitespace and tabs:	tab	separated	values

The end.
