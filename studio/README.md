# Fabrik (web)

Fabrik on the web: an internal AI asset creation platform built on
[fal.ai](https://fal.ai). Generate marketing imagery, enhance and edit listing
photos, virtually stage empty rooms, and turn stills into cinematic clips — all
from one place, with every result saved to a local library.

This app is **self-contained**. The static marketing site in the repository root
is untouched and still deploys to GitHub Pages exactly as before.

---

## How it is put together

```
Browser  ──►  /api/fal/proxy  ──►  fal.ai
             (adds FAL_KEY)
```

The fal API key is never sent to the browser. The client is configured with
`proxyUrl: "/api/fal/proxy"`, so every request — including file uploads — is
routed through a server route that attaches credentials from the environment.

Three layers protect that route, because anyone who can reach it can spend your
fal credits:

| Layer | File | What it does |
| --- | --- | --- |
| Session gate | `src/proxy.ts` | Redirects/401s any request without a valid signed session cookie |
| Re-check | `src/app/api/fal/proxy/route.ts` | Verifies the session again inside the proxy handler |
| Endpoint allowlist | same file | Rejects any fal endpoint not present in `src/lib/models.ts` |

The allowlist matters: without it, an authenticated user could drive *any* fal
model through your key, including far more expensive ones than the UI offers.

### Layout

```
src/
  app/
    page.tsx                  the studio (model picker, form, output, library)
    login/page.tsx            password gate
    api/auth/{login,logout}/  issues and clears the session cookie
    api/fal/proxy/route.ts    the credentialed fal proxy
  components/                 UI, all driven by the model registry
  lib/
    models.ts                 ← the model catalogue. Most edits happen here.
    fal.ts                    client config, output parsing, error formatting
    library.ts                IndexedDB asset history
    auth.ts                   cookie signing and password check
  proxy.ts                    the session gate (Next 16 "proxy" convention)
```

---

## Running it locally

```bash
cd studio
npm install
cp .env.example .env.local     # then fill in the three values
npm run dev                    # http://localhost:3000
```

You need all three environment variables set or the app will not let anyone in:

| Variable | What it is |
| --- | --- |
| `FAL_KEY` | Your fal API key, from <https://fal.ai/dashboard/keys>. Server-side only — never prefix it with `NEXT_PUBLIC_`. |
| `STUDIO_PASSWORD` | The shared password used to sign in. Make it long. |
| `SESSION_SECRET` | Signs the session cookie. Generate with `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` |

Changing `SESSION_SECRET` invalidates every existing session, which is the fastest
way to sign everyone out.

---

## Deploying

Vercel is the least-friction option, since the proxy needs a Node runtime.

1. Push this branch to GitHub.
2. In Vercel, import the repository and set **Root Directory** to `studio`.
3. Add `FAL_KEY`, `STUDIO_PASSWORD`, and `SESSION_SECRET` under
   **Settings → Environment Variables**.
4. Deploy.

Any host that runs a Node.js Next.js app works the same way — the studio has no
database and no other services to provision.

> **This app cannot be deployed to GitHub Pages.** Pages serves static files
> only, and a static build has nowhere to hide `FAL_KEY`. The marketing site at
> the repository root is unaffected and continues to deploy there.

---

## The model catalogue

Everything the studio can do is declared as data in
[`src/lib/models.ts`](src/lib/models.ts). The UI reads that file: the picker, the
input form, the validation, and the proxy allowlist are all generated from it.

Adding a model means adding one entry — no UI code changes:

```ts
{
  id: "my-model",                        // internal slug, stored with each asset
  endpointId: "fal-ai/some/endpoint",    // the fal endpoint
  title: "My model",
  blurb: "One line on when to reach for this.",
  category: "enhance",                   // groups it in the sidebar
  outputKind: "image",                   // "image" | "video"
  eta: "~20s",
  docsUrl: "https://fal.ai/models/fal-ai/some/endpoint",
  fields: [
    { name: "prompt", label: "Prompt", type: "textarea", required: true },
    { name: "image_url", label: "Source image", type: "image", required: true },
  ],
}
```

Each `field.name` is sent to fal **verbatim**, so it has to match that model's
documented input schema. Available field types: `text`, `textarea`, `select`,
`number`, `boolean`, `image`, `images`. A `number` field with `min`, `max`, and
`step` renders as a slider; `image` fields upload to fal storage and pass a URL.

### Verify endpoint IDs before you rely on them

The catalogue ships with a starting set aimed at real estate work — FLUX and
the Nano Banana family (including Nano Banana Pro) for generation and editing,
Clarity/AuraSR for upscaling, Kontext for sky replacement and staging, and
Kling 3 Pro and Seedance for image-to-video.

The Nano Banana family and Kling 3 Pro entries were verified against current
fal schema documentation (August 2026), including v3's renamed
`start_image_url` field. **The remaining entries — FLUX, Clarity, AuraSR,
BiRefNet, Kontext, Seedance — were written without access to fal's live model
gallery, and fal versions models regularly.** Before leaning on any of them in
client work, open its `docsUrl` and confirm the endpoint ID and field names
still match. Symptoms of a drifted schema:

- a validation error naming a field you are sending, or one you are not
- a job that completes but produces no files

Both surface in the UI with a link to the model's fal page. Fixing one is a
`src/lib/models.ts` edit.

### Cost

Every generation is a paid fal call, and video is dramatically more expensive
than images. Nothing here caps or meters spend — set a budget alert in the fal
dashboard, and keep `STUDIO_PASSWORD` to people you trust with it.

---

## The asset library

Results are recorded in IndexedDB in the browser: model, full input payload,
output URL, and fal request id. That keeps the app stateless and free of
infrastructure, with two consequences worth knowing:

- **History is per-browser.** It is not shared across devices or teammates. To
  make it shared, swap the five functions in `src/lib/library.ts` for API calls
  — the UI does not change.
- **fal expires stored outputs.** Only URLs are kept, not file bytes, so old
  entries eventually point at files that no longer exist. The gallery shows a
  placeholder when that happens. **Download anything you intend to keep.**

"Re-run" reloads a past generation's exact inputs into the form, so you can tweak
one value and go again.

---

## Scripts

| Command | Does |
| --- | --- |
| `npm run dev` | Development server |
| `npm run build` | Production build |
| `npm start` | Serve a production build |
| `npm run lint` | ESLint |
| `npm run typecheck` | `tsc --noEmit` |

---

## Growing past a shared password

The single shared password is deliberate — it is the smallest thing that safely
protects a credentialed proxy. When the studio needs real accounts:

1. Replace `verifyPassword` / `createSessionToken` in `src/lib/auth.ts` with your
   identity provider.
2. Keep `src/proxy.ts` and the proxy's `isAuthenticated` pointed at the new check
   — both must stay in place.
3. Add per-user quotas in the proxy route before exposing it to clients. Without
   them, one user can exhaust your fal balance.
