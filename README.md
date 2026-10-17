# noteic.github.io

The website of [Noteic](https://noteic.github.io/), a free handwriting and note app for Windows, available in the [Microsoft Store](https://apps.microsoft.com/detail/9n8bpds8hvlw).

The pages are plain HTML. Sources live in `_src` (one file per page, plus the layout), and `_werkzeug/bauen.ps1` builds the site into the repository root:

```
powershell -NoProfile -ExecutionPolicy Bypass -File _werkzeug/bauen.ps1
```

`-Vorschau` builds a version for opening the files directly from disk. The site uses no cookies, no analytics and no external fonts or scripts.
