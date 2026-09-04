# Images

Photos, illustrations, and icons for mockups, placeholder content, and rendering tests.

## Layout

| Folder                            | Holds                                                                 |
| --------------------------------- | --------------------------------------------------------------------- |
| [`photos/`](photos)               | Photographic images, grouped by primary subject                         |
| [`illustrations/`](illustrations) | Drawn artwork — flat scenes, characters, backgrounds, patterns         |
| [`icons/`](icons)                 | Small interface marks, ideally SVG, ideally on a square canvas         |

## Formats

- **Photos:** `.jpg` for anything large, `.webp` or `.avif` when a modern-format sample
  is the point. `.png` only when transparency matters.
- **Illustrations:** `.svg` when the source is vector, `.png` when it is not.
- **Icons:** `.svg` when the source is vector, `.png` on a square canvas when it is not.
  512×512 is the default raster size here.

## Naming

- Lowercase, `kebab-case`, describing the subject: `mountain-lake.jpg`,
  `empty-state-box.svg`, `icon-download.svg`.
- Photos live in the subject categories defined in [`photos/README.md`](photos/README.md).
  People photos follow that document's fixed PNG sizes and structured naming pattern.
- Put the size in the name when several resolutions of one image exist:
  `mountain-lake-1920x1080.jpg`, `mountain-lake-320x180.jpg`.
- Keep single files under about 5 MB. This repository is cloned for its samples, not
  for its weight.

## Compression

Compress an image before committing it. The pixel dimensions and the visible colors stay
as they are: this removes what the encoding wastes, not what the image shows. Never
resize, crop, or convert an image to a different format to save space, because that
changes the sample itself and the file name records the resolution.

```bash
brew install pngquant oxipng jpegoptim
```

A PNG takes two passes. `pngquant` reduces it to a palette, then `oxipng` packs the
result losslessly:

```bash
pngquant --quality=95-100 --speed 1 --force --ext .png icon-download-512x512.png
oxipng -o max --strip safe -a icon-download-512x512.png
```

`pngquant` leaves a file alone and exits with 99 when it cannot hold quality at 95. That
is the intended outcome for photographic artwork and smooth gradients, which band once
they are quantized. Run `oxipng` afterwards on every file either way: it compresses what
`pngquant` skipped, and it reverses the small increase `pngquant` leaves on a file that
was already compressed, so the pair is safe to run a second time. The `-a` flag drops an
alpha channel that is fully opaque, which costs about a quarter of the file and shows
nothing.

A JPEG takes one lossless pass:

```bash
jpegoptim --strip-all --all-progressive mountain-lake-1920x1080.jpg
```

All three commands accept several files at once, and `pngquant` reports 99 if it skipped
any of them. Open the result next to the original before committing it; if the two differ
where a reader would notice, keep the original and compress it losslessly instead.

## Sources

Every image in this folder was **generated for this repository**, and is covered by its
[LICENSE](../LICENSE). None of them photograph or portray anything real — see
[Generated content](../README.md#generated-content) in the root README.

An image that comes from somewhere else keeps its own license, and is listed here with its
source, author, and terms before it is added. Only assets that are free to redistribute
are accepted.
