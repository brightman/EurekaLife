# EurekaLife website

- This directory (`~/Documents/EurekaLife/apps/wiselife-website/`) is the canonical EurekaLife website source. Do not place new website implementation in the App's `prototype/` directory.
- Read `README.md` and `docs/INDEX.md` for page versions, preview commands, migration and deployment records. Keep current documentation under `docs/`, update existing topics before creating new ones, record actual verification and release status, preserve historical evidence, and update `docs/INDEX.md` for changes.
- The site uses static HTML/CSS/JavaScript and local assets. It does not need the Vessel HTTP API or an App build.
- Keep `index.html` and `index-next.html` synchronized. Preserve the independent `launch-preview/`, `design-preview/`, `design-preview-v2/` and `compare-designs/` entries until a version is explicitly selected as the homepage.
- The copies in this site's product demos are presentation fixtures. The native App and its current interaction prototypes are maintained separately; the verified sources are `../wrist-notes/` and `../wiselife-mac/` (2026-11-08).
- Preserve historical screenshots and reports. Write new migration checks to the migration evidence directory using `WISELIFE_VERIFY_OUTPUT`.

- The website has its own `package-lock.json` and Playwright dev dependency. Use `npm ci`; do not depend on Vessel node_modules. The static preview only needs Python.
- Earlier directory moves are recorded as historical events. Verify current paths and deployment before relying on old migration state.
