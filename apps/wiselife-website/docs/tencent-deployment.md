# Tencent Cloud website deployment

> 类型：发布与恢复说明 · 状态：current · 更新：2026-11-08

Current source (verified 2026-11-08): `~/Documents/EurekaLife/apps/wiselife-website/`. The earlier `~/Documents/WiseLife/wiselife-website/` path is no longer present. Historical migration facts remain in [directory migration](directory-migration.md).

## Current deployment

- Public URL: https://wiselife.karama.cloud
- Host: Tencent Cloud `81.71.98.127`; SSH identity `root`, existing `~/.ssh/id_ed25519_tencent_ecs` key.
- Web server: Caddy; configuration `/etc/caddy/Caddyfile`; document root `/opt/wiselife-site/current`.
- Active release: `/opt/wiselife-site/releases/20261108T140259Z-hd-v2`.
- Previous release retained for rollback: `/opt/wiselife-site/releases/20261108T132224Z-eurekalife`.
- 245 public files, 49 changed from the previous release, including new `website-english.js`.
- Website demos now consistently use English: iPhone UI and sample content, Mac models / Knowledge, and Watch recording / sync states. Existing Chinese or Japanese preferences in website storage no longer change the presentation language.
- Regenerated 3× device screenshots, alternative preview screens, the 27-second walkthrough and its poster. Eight source screenshots passed an Apple Vision check for remaining Han characters. The English video caption track is the default on earlier demonstration routes.
- Privacy Policy and Terms are English translations of the existing text. Their underlying terms and data handling statements were not changed.
- Only website demo copies changed. Native app and standalone product-prototype language support remain separate. Historical supplied reference images and evidence remain unchanged.
- Four preexisting local Mac JS/CSS differences remain unpublished: apply the translation to the production JS baseline and retain production CSS. Published Mac screenshots were captured from that staged version.
- Uploaded hashes and Caddy readability verified before guarded activation; no Caddy restart or configuration change. All 49 changed files also match over HTTPS. Eleven live demo states, desktop/mobile homepage, legal pages and a stored Chinese-language preference passed online checks.
- Local checks: four legal tests; 320–1920px responsive/interaction checks; 11 English demo states; 30 image-density checks at three widths, preserving the known user-selected hero resolution exception. Capture scripts require populated demo content before taking screenshots.
- Current evidence: [deployment](verification/english-interface-20261108/deployment.json), [English states](verification/english-interface-20261108/english-check.json), [image audit](verification/english-interface-20261108/asset-audit.json), [media checks](verification/english-interface-20261108/media-checks.json), [public changes](verification/english-interface-20261108/public-changes.json).


This task does not create a Git commit, push, TestFlight release or new domain. The existing TestFlight link is unchanged.

## Page mapping

- `/` and `/index-next.html`: HD V2 homepage, generated with `python3 scripts/sync-homepage.py`.
- `/design-preview-v2/`: independent entry for the same V2 implementation.
- `/index-before-v2.html`: previous default homepage, retained for comparison.
- `/design-preview/`: V1 layout retained, display brand updated to EurekaLife.
- `/compare-designs/`: V1 / V2 and reference / V2 comparison.
- `/product-demos/iphone/`, `/product-demos/watch/`, `/product-demos/mac/#models`: copies of the actual current interaction prototypes, with sample data.
- `/iphone-day.html`, `/watch-recorder.html`: earlier product demonstration routes, preserved.
- `/privacy/`, `/terms/`: existing legal pages.

The Mac website copy adds `website-entry.js` to open `#models` using existing prototype controls. The original `#knowledge` view remains available; upstream layout, model data and native App sources are unchanged.

Keep `index.html` and `index-next.html` synchronized. Brand assets come from `apps/wrist-notes/design/brand/wiselife-icon-v1/`. The PNG screenshot masters and provenance records remain local; the public pages serve optimized WebP images.

## Release procedure

1. Validate the selected page locally: `npm run test:legal`, `npm run test:design`, and `node scripts/audit-hd-assets.cjs` with the local server running.
2. Run `python3 scripts/package-release.py`. It creates a timestamped archive, public file manifest and evidence. Only public HTML/CSS/JS/media/fonts/licenses are included; docs, scripts, tests, Git, local configuration and source PNG masters are excluded. The version comparison’s design-reference image is intentionally public.
3. Serve the packaged directory locally and check asset loading and real prototype rendering before activation.
4. Upload the archive and uniquely named SHA-256 manifest. Extract to a new directory under `/opt/wiselife-site/releases/`; verify archive and every file hash, and check readability as `caddy`.
5. Hold `/opt/wiselife-site/deploy.lock`, compare the current symlink against the expected previous release, and atomically replace it. Abort if another deployment has changed the active target.
6. Run live browser checks using `WISELIFE_ORIGIN=https://wiselife.karama.cloud`; use a new `WISELIFE_VERIFY_OUTPUT` directory. Run `WISELIFE_VERIFY_OUTPUT=docs/verification/testflight-20261031 python3 scripts/verify-release.py` to compare public hashes and verify video range support. Retain the old release.

The packaging script does not deploy automatically. Deployment and rollback require authorization for their target environment.

## Rollback for this release

The previous production release is retained. Verify the active target before a guarded atomic switch:

```sh
set -e
exec 9>/opt/wiselife-site/deploy.lock
flock -x 9
test "$(readlink /opt/wiselife-site/current)" = /opt/wiselife-site/releases/20261108T140259Z-hd-v2
ln -s /opt/wiselife-site/releases/20261108T132224Z-eurekalife /opt/wiselife-site/rollback-english-20261108
mv -Tf /opt/wiselife-site/rollback-english-20261108 /opt/wiselife-site/current
```

Recheck HTTPS and the expected homepage after switching. Never overwrite an unexpected active release.

## Historical verification (2026-10-31)

- [Current release and HTTPS hashes](verification/testflight-20261031/deployment.json): all 244 public files verified before activation; root and 12 key files checked via HTTPS, video byte range returns 206.
- [Live TestFlight checks](verification/testflight-20261031/live/testflight-check.json): 320 / 390 / 1440px layouts, two direct CTAs, correct new-tab destination, actual click opens Apple’s WiseLife beta page.
- [Local browser regression](verification/testflight-20261031/local/verification.json): 320–1920px, menus, dialogs, keyboard history, video, product routes and preserved V1 hashes. Four legal checks also passed.
- [Packaged page](verification/testflight-20261031/package-check.json), [public changes](verification/testflight-20261031/public-changes.json), [manifest](verification/testflight-20261031/public-sha256.json), [release metadata](verification/testflight-20261031/release.json). Four HTML/JS files changed; no files added or removed. Artwork and styles are byte-for-byte unchanged, so image density was not retested for this text/link update.
- Website and public beta-link verification only; no beta enrollment, App installation or native hardware test was performed.

## Earlier releases

- `20261031T135119Z-hd-v2`: Mac model-library screenshot and Apple Watch → iPhone → Mac order, 244 public files. [Verification](verification/mac-models-20261031/deployment.json).

- `20261031T132507Z-hd-v2`: complete Watch, selected hero and clickable tips, 242 public files. [Verification](verification/watch-hardware-20261031/deployment.json).

- `20261031T121307Z-hd-v2`: initial HD V2 release with 240 files. [Original verification](verification/hd-v2-20261031/deployment.json).

- `20261031T060113Z`: earlier homepage and logo update, 70 files. [Original verification](verification/tencent-20261031/results.json). Previous rollback target: `1.0.1-20261022`.
- Original standalone checkout and Git history are preserved in the [directory migration backup](directory-migration.md).

- `20261108T132224Z-eurekalife`: previous brand-renaming release, 244 files. [Evidence](verification/eurekalife-brand-20261108/deployment.json).
