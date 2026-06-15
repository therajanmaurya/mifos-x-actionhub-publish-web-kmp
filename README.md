# mifos-x-actionhub-publish-web-kmp

[![Release](https://img.shields.io/github/v/release/therajanmaurya/mifos-x-actionhub-publish-web-kmp?label=release&logo=github)](https://github.com/therajanmaurya/mifos-x-actionhub-publish-web-kmp/releases/latest)
[![PR Check](https://github.com/therajanmaurya/mifos-x-actionhub-publish-web-kmp/actions/workflows/pr-check.yaml/badge.svg)](https://github.com/therajanmaurya/mifos-x-actionhub-publish-web-kmp/actions/workflows/pr-check.yaml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)

> Composite GitHub Actions for KMP **Web** (Kotlin/JS browser distribution): build + deploy to GitHub Pages, Cloudflare Pages, Netlify, or Vercel.

## What this provides

5 composite sub-actions:

| Sub-action | Platform | Purpose |
|---|---|---|
| [`build/`](./build/) | — | Build Kotlin/JS browser distribution (`jsBrowserDistribution`) |
| [`gh-pages/`](./gh-pages/) | GitHub Pages | Deploy to `gh-pages` / `gh-pages-staging` / `gh-pages-preview` branch |
| [`cloudflare-pages/`](./cloudflare-pages/) | Cloudflare Pages | Deploy via Wrangler |
| [`netlify/`](./netlify/) | Netlify | Deploy via Netlify CLI |
| [`vercel/`](./vercel/) | Vercel | Deploy via Vercel CLI |

## Promotion ladder (per-host)

| Stage | gh-pages branch | Cloudflare env | Netlify env | Vercel env |
|---|---|---|---|---|
| **Stage 1 — preview** | `gh-pages-preview` | `preview` | `branch-deploy` | `preview` |
| **Stage 2 — staging** | `gh-pages-staging` | `staging` | `staging` | `staging` |
| **Stage 3 — production** | `gh-pages` | `production` | `production` | `production` |

Promotion = copy build output from previous stage branch (or trigger host's redeploy).

## Repository structure

```
.
├── README.md
├── LICENSE
├── CHANGELOG.md
├── action.yaml                                 ← root composite (gh-pages default)
├── .github/workflows/{pr-check,release}.yaml
├── build/, gh-pages/, cloudflare-pages/,
├── netlify/, vercel/                           ← 5 sub-actions
├── _shared/
│   └── scripts/
│       └── promotion-log-append.sh
└── examples/
    └── consumer-release-web.yml
```

## Quick start — gh-pages Stage 3 (production)

```yaml
- uses: openMF/mifos-x-actionhub-publish-web-kmp/gh-pages@v2.0.0
  with:
    web_package_name: cmp-web
    target_stage:     production       # preview | staging | production
```

For the **full ladder run with approval gates**, see [`openMF/mifos-x-actionhub/.github/workflows/release-web.yaml`](https://github.com/openMF/mifos-x-actionhub/blob/main/.github/workflows/release-web.yaml).

## Supersedes (legacy repos)

| Old | New |
|---|---|
| `openMF/mifos-x-actionhub-build-web-app-kmp@v1.0.1` | `./build/@v2.0.0` |
| `openMF/mifos-x-actionhub-web-publish-kmp@v2.0.0` — gh-pages target | `./gh-pages/@v2.0.0` |
| `openMF/mifos-x-actionhub-web-publish-kmp@v2.0.0` — cloudflare-pages target | `./cloudflare-pages/@v2.0.0` |
| `openMF/mifos-x-actionhub-web-publish-kmp@v2.0.0` — netlify target | `./netlify/@v2.0.0` |
| `openMF/mifos-x-actionhub-web-publish-kmp@v2.0.0` — vercel target | `./vercel/@v2.0.0` |

## License

[Apache 2.0](./LICENSE)
