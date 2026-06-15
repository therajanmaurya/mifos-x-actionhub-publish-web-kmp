# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## v2.0.0 — Constellation consolidation (planned)

### Added

- `build/` — Kotlin/JS browser distribution build. Lifted from `openMF/mifos-x-actionhub-build-web-app-kmp@v1.0.1`.
- `gh-pages/` — Deploy to gh-pages-preview / gh-pages-staging / gh-pages branches based on `target_stage` input. Lifted from `openMF/mifos-x-actionhub-web-publish-kmp@v2.0.0` (gh-pages target).
- `cloudflare-pages/` — Wrangler deploy. Lifted from same repo (cloudflare-pages target).
- `netlify/` — Netlify CLI deploy. Lifted from same repo (netlify target).
- `vercel/` — Vercel CLI deploy. Lifted from same repo (vercel target).
- `_shared/scripts/promotion-log-append.sh` — append to deployment/PROMOTION_LOG.yaml.

### Supersedes (6-month deprecation window from 2026-09-01)

- `openMF/mifos-x-actionhub-build-web-app-kmp`
- `openMF/mifos-x-actionhub-web-publish-kmp` (rename: swap `web-publish` → `publish-web` for naming consistency with sister repos)

### Refs

- Epic: `actionhub-constellation-consolidation`
- Companion repos: `openMF/mifos-x-actionhub-publish-android-kmp@v2.0.0`, `openMF/mifos-x-actionhub-publish-apple-kmp@v2.0.0`, `openMF/mifos-x-actionhub-publish-desktop-kmp@v2.0.0`
- Orchestrator: `openMF/mifos-x-actionhub@v1.0.17` — adds `release-web.yaml` reusable workflow
