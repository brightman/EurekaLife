# EurekaLife website

Current source (verified 2026-11-08): `~/Documents/EurekaLife/apps/wiselife-website/`. All current homepage files, product demos, media, legal pages, and design alternatives are maintained here. See [documentation index](docs/INDEX.md) and [directory migration](docs/directory-migration.md).

Official website: https://wiselife.karama.cloud

iPhone beta: https://testflight.apple.com/join/HjdCdWJu

Static HTML, CSS, JavaScript and local media, served by Caddy on Tencent Cloud.

- `index.html`: selected HD V2 homepage, matching `index-next.html`. Run `python3 scripts/sync-homepage.py` after changing `design-preview-v2/index.html`.
- `iphone-day.html`: previous homepage and interactive iPhone prototype.
- `watch-recorder.html`: interactive Watch prototype.
- `assets/brand/`: website exports from the EurekaLife brand master.

From this directory, run `npm run dev` (equivalent to `python3 -m http.server 8789 --bind 127.0.0.1`). Preview: http://localhost:8789/. The existing preview remains available; stop it before starting another server on the same port.

For browser checks, install the website's own dependencies with `npm ci` and install Chromium with `npx playwright install chromium` if needed. With the server running, run `npm run test:legal` and `WISELIFE_VERIFY_OUTPUT=/tmp/wiselife-website-check npm run test:design`. Playwright is pinned in this project's lockfile; `PLAYWRIGHT_MODULE` can optionally select another installation. The static website itself has no build step or npm runtime dependency.

Website-only capture/render scripts live in `scripts/`, with policy tests in `Tests/`. App interaction prototypes and the original brand master remain with the App. The website source is now in the EurekaLife workspace. The former `~/Documents/WiseLife/wiselife-website/` location is absent as of 2026-11-08. Earlier moves and backups are historical records in the migration document. App interaction prototypes are at `../wrist-notes/prototype/` and `../wiselife-mac/prototype/`.

The embedded app is an interactive demo using sample data. See `docs/tencent-deployment.md` for deployment and rollback details.

## New local launch-page concept

Preview the independent English redesign at [`launch-preview/index.html`](launch-preview/index.html). It follows the global launch brief with eight sections and interactive product examples. This concept is preserved as an alternative; the public homepage uses HD V2.

## Design-reference preview

Preview the high-fidelity implementation of the supplied design at [`design-preview/index.html`](design-preview/index.html), or http://localhost:8789/design-preview/ when the local server is running. See [`design-preview/README.md`](design-preview/README.md) for the asset sources, interactions, and verification screenshots. This version is retained for comparison; HD V2 is the selected homepage.

## Second design-reference preview

The newer private-AI reference has an independent implementation at [`design-preview-v2/index.html`](design-preview-v2/index.html): http://localhost:8789/design-preview-v2/. Open [`compare-designs/index.html`](compare-designs/index.html) at http://localhost:8789/compare-designs/ to compare V1 / V2 or the supplied reference / V2. V2 now uses high-resolution photography, actual 3× product-prototype captures, and scalable device frames. It is selected for the public homepage; the previous default is preserved as `index-before-v2.html`. V1 retains its layout with the approved EurekaLife brand rename. See [`design-preview-v2/README.md`](design-preview-v2/README.md) for asset provenance, capture commands, and checks, and [`docs/tencent-deployment.md`](docs/tencent-deployment.md) for release status.

## English website presentation (2026-11-08)

The official website demos use English, including iPhone sample records and AI replies, Watch recording/sync states, and Mac models and Knowledge. `website-english.js` supplements the existing iPhone locale dictionary; the website forces English even when a previous demo session saved another language. Native app and standalone product-prototype languages are unchanged. `node scripts/verify-english-demos.cjs` checks 11 rendered states for untranslated text. Capture scripts verify populated UI before screenshots; the 27-second video, its poster and device screenshots are regenerated from English demo fixtures. Legal pages are English translations of the existing policies. See the deployment record for release status.
