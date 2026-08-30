# Videos

Short video clips for players, thumbnail generators, upload flows, and transcoding tests.

## Formats

`.mp4` (H.264/AAC) as the safe default, `.webm` (VP9/Opus) when an open-format sample is
needed. A clip that exists to test a specific codec or container says so in its name.

## Naming

- Lowercase, `kebab-case`, describing the content: `city-timelapse.mp4`,
  `countdown-10s.webm`.
- Add resolution or duration when it is the reason the file exists:
  `city-timelapse-720p.mp4`, `silence-30s.mp4`.

## Size

Keep clips short — a few seconds is usually enough to test a pipeline — and files under
about 20 MB. Git stores every version of a binary in full, so a large clip replaced twice
stays in the history three times.

## Sources

Clips recorded for this repository are covered by its [LICENSE](../LICENSE). A clip that
comes from somewhere else keeps its own license, and is listed here with its source,
author, and terms before it is added. Only assets that are free to redistribute are
accepted. Nothing has been added yet.
