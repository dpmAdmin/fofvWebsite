# Four One Five Visuals

This repository holds three things:

| | What it is | Where it runs |
| --- | --- | --- |
| **Marketing site** (repo root) | The public static site | GitHub Pages |
| **[`Fabrik/`](Fabrik/)** | Fabrik — native iOS + macOS asset creation app | Xcode → your devices |
| **[`studio/`](studio/)** | Fabrik on the web — the same tool as a Next.js app | Vercel (or any Node host) |

They are independent. Adding Fabrik changed nothing about how the marketing site
builds or deploys.

**Fabrik** is the AI asset creation tool: generate imagery, enhance and upscale
photos, replace skies, virtually stage empty rooms, and turn stills into
cinematic clips — all through [fal.ai](https://fal.ai).

- The **native app** uses *your own* fal key, stored in the Keychain. No server,
  no hosting. → [`Fabrik/README.md`](Fabrik/README.md)
  <br>⚠️ It has never been compiled — it was written without access to Xcode. See its README.
- The **web app** keeps one fal key server-side behind a password, for people who
  should not need their own fal account. → [`studio/README.md`](studio/README.md)

---

# Marketing site

A simple static website for Four One Five Visuals.

## Files

- `index.html` - page structure and copy
- `styles.css` - visual design and responsive layout
- `script.js` - mobile menu and automatic footer year

## GitHub Pages Setup

1. Create a new GitHub repository.
2. Upload these files to the root of the repo.
3. Go to **Settings > Pages**.
4. Under **Build and deployment**, choose **Deploy from a branch**.
5. Select the `main` branch and `/root` folder.
6. Save.

Your site will publish at your GitHub Pages URL. You can later connect `fouronefivevisuals.com` through your domain DNS settings.

## Easy edits

- Replace the email in `index.html` near the contact section.
- Swap placeholder visual blocks for real images/video embeds when ready.
- Edit service copy directly inside `index.html`.
