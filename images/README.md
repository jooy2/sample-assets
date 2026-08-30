# Images

Photos, illustrations, and icons for mockups, placeholder content, and rendering tests.

## Layout

| Folder                            | Holds                                                                 |
| --------------------------------- | --------------------------------------------------------------------- |
| [`photos/`](photos)               | Photographic images — landscapes, objects, people, textures            |
| [`illustrations/`](illustrations) | Drawn artwork — flat scenes, characters, backgrounds, patterns         |
| [`icons/`](icons)                 | Small interface marks, ideally SVG, ideally on a square canvas         |

## Formats

- **Photos:** `.jpg` for anything large, `.webp` or `.avif` when a modern-format sample
  is the point. `.png` only when transparency matters.
- **Illustrations:** `.svg` when the source is vector, `.png` when it is not.
- **Icons:** `.svg`. Ship a `.png` next to it only when a raster sample is needed.

## Naming

- Lowercase, `kebab-case`, describing the subject: `mountain-lake.jpg`,
  `empty-state-box.svg`, `icon-download.svg`.
- Put the size in the name when several resolutions of one image exist:
  `mountain-lake-1920x1080.jpg`, `mountain-lake-320x180.jpg`.
- Keep single files under about 5 MB. This repository is cloned for its samples, not
  for its weight.

## Sources

Images made for this repository are covered by its [LICENSE](../LICENSE). An image that
comes from somewhere else keeps its own license, and is listed here with its source,
author, and terms before it is added. Only assets that are free to redistribute are
accepted. Nothing has been added yet.
