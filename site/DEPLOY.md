# Deploying the VoidTweaks site

The site is plain static HTML/CSS/JS in `site/` — no build step.

## GitHub Pages (already wired)

`.github/workflows/pages.yml` publishes `site/` on every push to `main`.
**One-time:** GitHub repo → **Settings → Pages → Build and deployment → Source: GitHub Actions**.
After the next push it's live at `https://voiduserfr.github.io/VoidTweaks-Windows/`.

## Cloudflare Pages (recommended — faster, free custom domain)

1. Go to **dash.cloudflare.com → Workers & Pages → Create → Pages → Connect to Git**.
2. Pick the **VoidTweaks-Windows** repo.
3. Build settings:
   - **Framework preset:** None
   - **Build command:** *(leave empty)*
   - **Build output directory:** `site`
4. **Save and Deploy.** You get a `*.pages.dev` URL in ~30s; every push auto-deploys.
5. (Optional) **Custom domain:** Pages project → Custom domains → add your domain, follow the DNS step.

## The download link-locker (income)

Open `site/assets/config.js` and set:

```js
lockerUrl: "https://work.ink/xxxx/voidtweaks",  // your locked link → GitHub release
lockerName: "work.ink",
```

- The locker's **destination** should be the GitHub release (or a direct asset URL).
- Set the locker to **1 checkpoint/step**.
- Leave `lockerUrl: ""` to send Download straight to GitHub (no ad-step).
- With a locker set, an honest "no ads? get it on GitHub →" fallback shows automatically.

Recommended lockers: **work.ink** or **Lootlabs** (community-friendly, good pay). Linkvertise works but users dislike it.
