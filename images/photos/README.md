# Photos

Photographic images are grouped by their primary visible subject so consumers can browse
the collection without scanning one large directory.

## Categories

| Folder                                      | Holds                                                        |
| ------------------------------------------- | ------------------------------------------------------------ |
| [`backgrounds/`](backgrounds)               | Scenic or atmospheric images suited to large-area backgrounds |
| [`food-and-drink/`](food-and-drink)         | Food, ingredients, drinks, and serving scenes                |
| [`nature/`](nature)                         | Plants, wildlife, and natural details                         |
| [`objects/`](objects)                       | Products, tools, and still-life arrangements                  |
| [`people/`](people)                         | Fictional people isolated on transparent backgrounds          |
| [`places/`](places)                         | Architecture, interiors, and identifiable types of places     |
| [`transportation/`](transportation)         | Vehicles and other means of transport                         |

Choose the category from the image's main subject, not a possible use. When an image
could fit several categories, prefer the subject a viewer would name first. Add a new
category only when several assets share a clear subject that does not fit this table.

## General rules

- Use lowercase `kebab-case` names that describe the subject.
- Put the pixel dimensions at the end of every raster image name.
- Use `.jpg` for ordinary opaque photos and `.png` only when transparency matters.
- Keep each file under about 5 MB.
- Generated photographs must not imitate a real person, brand, logo, or identifiable
  private place.

## People

All images in [`people/`](people) portray wholly fictional people. Generate each person
without a reference photograph or the name of a real person, and do not intentionally
resemble a public figure or any other identifiable individual.

This collection is **adults only**. Every portrayed person must be at least 18 years old;
do not add babies, children, or teenagers.

People assets use these fixed specifications:

| Framing       | Canvas       | Format | Composition                                      |
| ------------- | ------------ | ------ | ------------------------------------------------ |
| `upper-body`  | 1024×1024 px | PNG    | Head and torso visible; suitable for an avatar   |
| `full-body`   | 1024×1536 px | PNG    | Entire figure visible from head through both feet |

- The background must be genuinely transparent, not white, gray, checkerboard, or a
  flat color. Preserve an alpha channel and leave clear space around the figure.
- Use natural, non-branded clothing. Do not include text, logos, watermarks, props, or
  recognizable uniforms.
- Use a neutral, approachable pose and expression.
- Give every person a random fictional name. A name labels the sample only and does not
  assert or imply a real identity.

Name each file using this pattern:

```text
<given-name>-<family-name>-<age-group>-<gender>-<framing>-<width>x<height>.png
```

Allowed age groups are `young-adult` (18–29), `adult` (30–44), `middle-aged` (45–64),
and `senior` (65+). Allowed gender values are `female`, `male`, and `nonbinary`. For
example:

```text
mira-velen-middle-aged-female-upper-body-1024x1024.png
```

Use this prompt pattern for future generations, adding only appearance and plain-clothing
details needed to keep the collection varied:

```text
Create one wholly fictional adult <age-group> <gender> person, age 18 or older, without
a reference image or the name of a real person. Use natural photorealistic detail and
plain, unbranded clothing. Frame the person as <upper-body|full-body> on a genuinely
transparent background with generous clear margins. Preserve fine hair edges, but add
no backdrop, glow, outline, floor, shadow, text, logo, watermark, prop, or recognizable
uniform. Do not imitate a public figure or any other identifiable person. Never portray
a baby, child, or teenager.
```
