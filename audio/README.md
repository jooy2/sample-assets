# Audio

Sound files for players, waveform rendering, notification sounds, and decoding tests.

## Formats

`.mp3` for compressed samples, `.wav` for uncompressed ones, `.ogg` or `.m4a` when the
container itself is what is being tested.

## Naming

- Lowercase, `kebab-case`, describing the sound: `notification-ping.mp3`,
  `piano-loop.wav`, `crowd-ambience.ogg`.
- Add the duration when it matters: `silence-5s.wav`, `beep-500ms.mp3`.
- Note a non-standard sample rate or channel count in the name when that is the point:
  `tone-440hz-mono-8khz.wav`.

## Size

Keep files short and under about 10 MB. Prefer a five-second loop over a five-minute
track.

## Sources

Audio produced for this repository is covered by its [LICENSE](../LICENSE). Audio that
comes from somewhere else keeps its own license, and is listed here with its source,
author, and terms before it is added. Only assets that are free to redistribute are
accepted. Nothing has been added yet.
