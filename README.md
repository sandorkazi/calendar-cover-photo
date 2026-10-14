# calendar-cover-photo

Generate 210×254 calendar day cover photos with a faded background, frame overlay, and month/day labels.

Built on [ImageMagick 7](https://imagemagick.org/) (`magick`) + `curl` + Bash.

## Quick start

```bash
./day.sh OKT 11
# -> days/OKT-11.png

./day.sh OKT 18 -b assets/backgrounds/games/heat.webp
# -> days/OKT-18.png

./day.sh DEC 24 -b assets/backgrounds/occasions/mulled.jpg -s xmas
# -> days/DEC-24-xmas.png
```

## Requirements

- Bash
- ImageMagick 7 (`magick` on `PATH`)
- `curl`
- A font providing `C059-Bold` (e.g. `gsfonts` on Linux), or override with `FONT=`

Check:

```bash
magick -version
curl --version
magick -list font | grep -i C059
```

## Usage

```text
Usage: day.sh MONTH DAY [-s SUFFIX] [-f FRAME] [-b BACKGROUND] [-h]

  MONTH            Month label (rendered uppercased, e.g. OKT)
  DAY              Day label (e.g. 11)
  -s SUFFIX        Appended to output as "-SUFFIX" (default: none)
  -f FRAME         Frame overlay image path (default: assets/templates/empty-transparent.png)
  -b BACKGROUND    Background image path, http(s):// URL, or bare
                   host/path (https by default, http fallback on 404)
  -h               Show this help and exit
```

Background (`-b`) accepts:

1. Local file, e.g. `-b assets/backgrounds/games/heat.webp`
2. Full URL, e.g. `-b https://example.com/photo.jpg`
3. Bare host/path without scheme (HTTPS first, HTTP fallback on 404), e.g. `-b example.com/photo.jpg`

If `-b` is omitted, the default white background is used.

### Styling overrides

| Env var      | Default | Description                    |
|--------------|---------|--------------------------------|
| `CARD_W`     | `210`   | Output width in px             |
| `CARD_H`     | `254`   | Output height in px            |
| `BG_OPACITY` | `40%`   | Background alpha after fading  |
| `FONT`       | `C059-Bold` | Font for month/day text    |
| `MONTH_SIZE` | `50`    | Month label pointsize          |
| `DAY_SIZE`   | `180`   | Day label pointsize            |

Example:

```bash
BG_OPACITY=25% FONT=DejaVu-Sans-Bold ./day.sh OKT 11 -b assets/backgrounds/games/anachrony.png
```

## Layout

```text
.
├── day.sh                    # generator script
├── assets/
│   ├── backgrounds/
│   │   ├── games/            # board-game backgrounds
│   │   └── occasions/        # seasonal / occasion backgrounds
│   └── templates/
│       ├── white.png         # base card + default background
│       ├── empty-transparent.png # default frame overlay
│       ├── empty.png
│       ├── empty.svg         # vector source of the frame
│       └── nothing.png
└── days/                     # generated output (git-ignored, e.g. OKT-11.png)
```

The script resolves paths relative to its own location, so it works both from the repo root and from `scripts/` (legacy location).

## How it works

1. Resolves `BACKGROUND` to a local file (downloading to a temp file if it is a URL).
2. Resizes with cover-crop to `CARD_W`×`CARD_H`, sets alpha to `BG_OPACITY`.
3. Composites: base (`white.png`) → faded background → frame overlay.
4. Annotates month (uppercased, white, centered) and day (black, centered).
5. Writes `days/${MONTH}-${DAY}[-SUFFIX].png`.

## License

MIT — see [LICENSE](LICENSE).
