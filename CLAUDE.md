# Four One Five Visuals — marketing site

This repository is **only** the public static marketing site: `index.html`,
`styles.css`, `script.js`, served by GitHub Pages from the repo root. There is
no build step and no framework.

## Fabrik is not in this repository

If a task mentions **Fabrik** — the fal.ai asset creation app, batch RAW
processing, exposure fusion, colour grading, the Vercel deploy at
`fabrik-ebon.vercel.app`, or the native iOS/macOS app — it belongs to a
different repository:

> **`dpmAdmin/fabrik`**, checked out at `/home/user/fabrik`

Work on Fabrik there, not here. Editing this repository will not change what is
deployed, and the change will silently appear to do nothing.

This repository once held early copies of both Fabrik apps (`studio/` and
`Fabrik/`). They were snapshots from before Fabrik was split out, they were
superseded, and they were deleted for exactly this reason — they were being
mistaken for the live app. They are still in git history.

### Telling them apart quickly

The deployed Fabrik web app has a **Batch** tab and a version stamp in its
header. Nothing in this repository does.

```sh
git -C /home/user/fabrik remote -v   # -> github.com/dpmAdmin/fabrik
```
