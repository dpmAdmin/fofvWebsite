# Four One Five Visuals

The public marketing site for Four One Five Visuals — a static site served by
GitHub Pages from this repository's root.

- `index.html` — page structure and copy
- `styles.css` — visual design and responsive layout
- `script.js` — mobile menu and automatic footer year

## Editing

- Replace the email in `index.html` near the contact section.
- Swap placeholder visual blocks for real images/video embeds when ready.
- Edit service copy directly inside `index.html`.

## GitHub Pages

**Settings → Pages → Build and deployment → Deploy from a branch**, `main` /
root. The site publishes at the GitHub Pages URL, and
`fouronefivevisuals.com` points at it through DNS.

Nothing here needs a build step: the three files above *are* the site.

---

## Looking for Fabrik?

**Fabrik lives in its own repository: [`dpmAdmin/fabrik`](https://github.com/dpmAdmin/fabrik).**
That is the only place it is developed, and the only place it deploys from
(Vercel → `fabrik-ebon.vercel.app`).

This repository used to carry two early copies of it — a `studio/` Next.js app
and a `Fabrik/` Xcode project. Both were snapshots taken *before* Fabrik was
split out, and both were superseded: everything in them was carried over to
`dpmAdmin/fabrik`, which has since gained batch RAW processing, exposure
fusion, the real-estate colour grading pipeline and much else that never
existed here. Keeping stale duplicates around only invited edits landing in the
copy that nothing deploys, so they were removed in favour of the one real home.

They remain in this repository's history if you ever want to read them:

```sh
git log --oneline -- studio Fabrik   # the commits that touched them
git show 4a30675                     # the last substantive change
```
