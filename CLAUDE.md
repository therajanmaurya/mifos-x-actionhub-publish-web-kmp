# CLAUDE.md — mifos-x-actionhub-publish-web-kmp (Tier 3 — Web hosts)

> **You are in a TIER-3 PUBLISH repo.** Before editing anything, check whether
> the change actually belongs in the **orchestrator** (`openMF/mifos-x-actionhub`).
> Full decision guide: [`mifos-x-actionhub/CONTRIBUTING.md`](https://github.com/openMF/mifos-x-actionhub/blob/main/CONTRIBUTING.md)

## The 3-tier chain

```
Consumer (kmp-project-template + forks)        Tier 1 — thin wrapper
    └─ uses @v1.0.X →
openMF/mifos-x-actionhub                       Tier 2 — orchestrator
    └─ uses @v2.0.X →
publish-android-kmp                            Tier 3 — Android ladder
publish-apple-kmp                              Tier 3 — iOS + macOS
publish-desktop-kmp                            Tier 3 — Windows + Linux
publish-web-kmp (THIS REPO)                    Tier 3 — Web hosts
```

This repo handles Kotlin/JS browser-distribution deploys across multiple hosts
via a single `host` input (`host: gh-pages | cloudflare-pages | netlify | vercel`).

## What lives here (Web-specific)

| Concern | File | Owns |
|---|---|---|
| Ladder workflow | `.github/workflows/release.yaml` | rungs: preview → staging → production (per-host branch / env) |
| Composite actions | `{host}/action.yaml` | per-host deploy (gh-pages push, wrangler, netlify-cli, vercel) |
| Validate-secrets preflight | `release.yaml#validate-secrets` | per-host: gh-pages=none, cloudflare/netlify/vercel=1 token each |

## "Should this change go HERE or in the orchestrator?"

### ✅ Edit HERE when…
- Adding a new web host (e.g. `aws-s3-cloudfront`, `firebase-hosting`, `surge`)
- Changing how the Kotlin/JS distribution is built (`jsBrowserDistribution`, webpack tweaks)
- Updating wrangler / netlify-cli / vercel-cli pinned versions
- Changing per-host environment promotion logic (branch flip, env variable)
- Changing GitHub Environment names (`web-cloudflare-pages-preview` → …)
- Adjusting per-host `validate-secrets` env list

### ❌ DON'T edit here — go to orchestrator when…
- Changing the consumer-facing `workflow_dispatch` form (the `web_rung`, `web_host` choices live in `release-multi-platform-v2.yaml`)
- Adding cross-platform validation
- Changing the auto-version_tag logic

## Versioning

| Bump | When |
|---|---|
| Patch (`v2.0.4` → `v2.0.5`) | any change inside the ladder |
| Minor (`v2.0.X` → `v2.1.0`) | new host added (e.g. `firebase-hosting`) |
| Major (`v2.X.X` → `v3.0.0`) | breaking — host removed, secret renamed |

After merging:
1. Tag `v2.0.{X+1}` on `main`
2. Bump orchestrator's `publish-web-kmp/.github/workflows/release.yaml@v2.0.{X}` → `@v2.0.{X+1}`
3. Tag orchestrator patch, bump consumer wrappers

## Web secret schema (per host — canonical names match V2_GUIDE.md)

| Host | Secrets required |
|---|---|
| `gh-pages` | (none — uses GITHUB_TOKEN) |
| `cloudflare-pages` | `cloudflare_api_token` |
| `netlify` | `netlify_auth_token` |
| `vercel` | `vercel_token` |

## Don't

- ❌ Don't reference floating tags
- ❌ Don't deploy to multiple hosts in one workflow run — one host per dispatch
- ❌ Don't hardcode site IDs / project IDs — pass them as inputs from the orchestrator

## Always

- ✅ Tag immediately after merge
- ✅ Bump orchestrator's ref pin in the same coordinated release
- ✅ When adding a new host, add a `case` branch in `validate-secrets` AND to the orchestrator's `web_host` choices
- ✅ Match canonical lowercase snake_case secret names
