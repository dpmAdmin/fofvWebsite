# Four One Five Visuals

This repository holds two separate things:

| | What it is | Where it deploys |
| --- | --- | --- |
| **Marketing site** (repo root) | The public static site | GitHub Pages |
| **[`studio/`](studio/)** | Internal AI asset creation platform, powered by fal.ai | Vercel (or any Node host) |

The two are independent — the studio is a Next.js app in its own folder with its
own dependencies, and adding it changed nothing about how the marketing site
builds or deploys.

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

---

# FOFV Studio

An internal tool for generating and editing listing media with AI: text-to-image,
photo enhancement and upscaling, sky replacement and twilight conversion, virtual
staging, and image-to-video.

It needs a server, because the fal API key must never reach the browser — so it
**cannot** run on GitHub Pages alongside the marketing site. See
**[`studio/README.md`](studio/README.md)** for setup, deployment, and how to add
models to the catalogue.

```bash
cd studio
npm install
cp .env.example .env.local   # add FAL_KEY, STUDIO_PASSWORD, SESSION_SECRET
npm run dev
```
