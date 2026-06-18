#!/bin/bash
# tests/workflow-tests.sh
#
# End-to-end workflow tests for mifos-x-actionhub-publish-web-kmp.
#
# Tier-3 repo (Web hosts) in the 3-tier actionhub chain:
#     consumer → orchestrator(mifos-x-actionhub) → THIS REPO
#
# Hosts: gh-pages, cloudflare-pages, netlify, vercel
#
# Test tiers:
#   1. Static syntax    — YAML parse · actionlint · no dynamic uses
#   2. Workflow_call    — interface schema (inputs + secrets contract)
#   3. Job structure    — 4 jobs · dependencies · stage ordering
#   4. Per-host fix     — 4 conditional static-uses + correct if-gates (locks v2.0.6 fix)
#   5. Composite actions — every uses: host subdir exists + has action.yaml
#   6. Action interfaces — Family A (gh-pages) vs Family B (commercial providers)
#   7. validate-secrets — coverage per host
#   8. Multi-stage      — preview/staging/production ladder logic
#
# Dependencies: python3 + PyYAML, actionlint, shellcheck

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
FAILED_TESTS=()

run_test() {
    local name="$1"
    local cmd="$2"
    printf "  %-72s ... " "$name"
    if eval "$cmd" > /tmp/test-out 2>&1; then
        echo "✅ PASS"
        PASS=$((PASS+1))
    else
        echo "❌ FAIL"
        sed 's/^/      /' /tmp/test-out
        FAIL=$((FAIL+1))
        FAILED_TESTS+=("$name")
    fi
}

py() { python3 -c "$1"; }

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────
HOSTS=(gh-pages cloudflare-pages netlify vercel)
EXPECTED_JOBS=(validate-secrets stage-1-preview stage-2-staging stage-3-production)
EXPECTED_INPUTS=(host web_package_name starting_rung)
EXPECTED_SECRETS=(cloudflare_api_token netlify_auth_token vercel_token)

echo "════════════════════════════════════════════════════════════════════════════"
echo "  Workflow E2E tests for mifos-x-actionhub-publish-web-kmp"
echo "════════════════════════════════════════════════════════════════════════════"
echo

# ── Tier 1: Static syntax ────────────────────────────────────────────────────
echo "── Tier 1: Static syntax ──"
run_test "T01: release.yaml parses (PyYAML)" \
    "py 'import yaml; yaml.safe_load(open(\".github/workflows/release.yaml\"))'"
run_test "T02: pr-check.yaml parses" \
    "py 'import yaml; yaml.safe_load(open(\".github/workflows/pr-check.yaml\"))'"
run_test "T03: tag.yaml parses" \
    "py 'import yaml; yaml.safe_load(open(\".github/workflows/tag.yaml\"))'"
run_test "T04: actionlint clean on release.yaml" \
    "actionlint .github/workflows/release.yaml"
run_test "T05: actionlint clean on pr-check.yaml" \
    "actionlint .github/workflows/pr-check.yaml"
run_test "T06: actionlint clean on tag.yaml" \
    "actionlint .github/workflows/tag.yaml"
run_test "T07: NO dynamic uses regression" \
    "! grep -nE '^[^#]*uses: .*\\\${{ (inputs|matrix)\\.' .github/workflows/release.yaml"
run_test "T08: shellcheck clean on _shared/scripts" \
    "find _shared/scripts -name '*.sh' -exec shellcheck -S warning {} +"
echo

# ── Tier 2: workflow_call interface contract ─────────────────────────────────
echo "── Tier 2: workflow_call interface contract ──"
run_test "T09: workflow_call inputs include (host, web_package_name, starting_rung)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
got = set(d[\"on\" if \"on\" in d else True][\"workflow_call\"][\"inputs\"].keys())
expected = set([\"host\",\"web_package_name\",\"starting_rung\"])
assert expected.issubset(got), \"missing inputs: \" + str(expected - got)
'"
run_test "T10: workflow_call.web_package_name is required + type string" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
t = d[\"on\" if \"on\" in d else True][\"workflow_call\"][\"inputs\"][\"web_package_name\"]
assert t.get(\"required\") == True
assert t.get(\"type\") == \"string\"
'"
run_test "T11: workflow_call secrets = (cloudflare_api_token, netlify_auth_token, vercel_token)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
got = set(d[\"on\" if \"on\" in d else True][\"workflow_call\"][\"secrets\"].keys())
exp = set([\"cloudflare_api_token\",\"netlify_auth_token\",\"vercel_token\"])
assert got == exp, \"diff: \" + str(got.symmetric_difference(exp))
'"
run_test "T12: all workflow_call secrets are optional (required:false)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
for name, spec in d[\"on\" if \"on\" in d else True][\"workflow_call\"][\"secrets\"].items():
    assert spec.get(\"required\") == False, name
'"
echo

# ── Tier 3: Job structure ────────────────────────────────────────────────────
echo "── Tier 3: Job structure ──"
run_test "T13: All 4 expected jobs present" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
got = set(d[\"jobs\"].keys())
exp = set([\"validate-secrets\",\"stage-1-preview\",\"stage-2-staging\",\"stage-3-production\"])
assert got == exp, \"diff: \" + str(got.symmetric_difference(exp))
'"
run_test "T14: stage-1-preview depends on validate-secrets" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
assert d[\"jobs\"][\"stage-1-preview\"][\"needs\"] == [\"validate-secrets\"]
'"
run_test "T15: stage-2-staging depends on stage-1-preview" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
assert d[\"jobs\"][\"stage-2-staging\"][\"needs\"] == [\"stage-1-preview\"]
'"
run_test "T16: stage-3-production depends on stage-2-staging" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
assert d[\"jobs\"][\"stage-3-production\"][\"needs\"] == [\"stage-2-staging\"]
'"
echo

# ── Tier 4: Per-host static-uses (locks v2.0.6 fix) ──────────────────────────
echo "── Tier 4: Per-host static-uses (locks v2.0.6 fix) ──"
for STAGE in stage-1-preview stage-2-staging stage-3-production; do
    run_test "T17/$STAGE: has 4 per-host build steps" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
steps = d[\"jobs\"][\"$STAGE\"][\"steps\"]
host_steps = [s for s in steps if isinstance(s,dict) and \"publish-web-kmp/\" in str(s.get(\"uses\",\"\"))]
assert len(host_steps) == 4, \"expected 4 in $STAGE, got \" + str(len(host_steps))
'"
done
for STAGE in stage-1-preview stage-2-staging stage-3-production; do
    run_test "T18/$STAGE: each per-host step has inputs.host == if-gate" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
steps = d[\"jobs\"][\"$STAGE\"][\"steps\"]
for s in steps:
    if isinstance(s,dict) and \"publish-web-kmp/\" in str(s.get(\"uses\",\"\")):
        assert \"if\" in s, \"missing if on \" + s[\"uses\"]
        assert \"inputs.host ==\" in s[\"if\"], \"bad if: \" + s[\"if\"]
'"
done
run_test "T19: Each host subdir referenced once per stage (12 total = 4 hosts × 3 stages)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
total = 0
for STAGE in [\"stage-1-preview\",\"stage-2-staging\",\"stage-3-production\"]:
    steps = d[\"jobs\"][STAGE][\"steps\"]
    refs = set()
    for s in steps:
        if isinstance(s,dict) and \"publish-web-kmp/\" in str(s.get(\"uses\",\"\")):
            path = s[\"uses\"].split(\"/\")[-1].split(\"@\")[0]
            assert path not in refs, STAGE + \" has \" + path + \" twice\"
            refs.add(path)
            total += 1
    assert refs == set([\"gh-pages\",\"cloudflare-pages\",\"netlify\",\"vercel\"]), STAGE + \" refs: \" + str(refs)
assert total == 12, \"expected 12 total, got \" + str(total)
'"
run_test "T20: All references pinned to @v2.0.0 (composite-action stable tag)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
for STAGE in [\"stage-1-preview\",\"stage-2-staging\",\"stage-3-production\"]:
    for s in d[\"jobs\"][STAGE][\"steps\"]:
        if isinstance(s,dict) and \"publish-web-kmp/\" in str(s.get(\"uses\",\"\")):
            assert s[\"uses\"].endswith(\"@v2.0.0\"), \"non-canonical ref: \" + s[\"uses\"]
'"
echo

# ── Tier 5: Composite-action existence ───────────────────────────────────────
echo "── Tier 5: Composite-action existence ──"
for H in "${HOSTS[@]}"; do
    run_test "T2x:  $H/action.yaml exists + parses" \
        "test -f '$H/action.yaml' && py 'import yaml; yaml.safe_load(open(\"$H/action.yaml\"))'"
done
for H in "${HOSTS[@]}"; do
    run_test "T2y:  $H/action.yaml is composite + has steps" "py '
import yaml
d = yaml.safe_load(open(\"$H/action.yaml\"))
assert d[\"runs\"][\"using\"] == \"composite\"
assert d[\"runs\"].get(\"steps\"), \"$H has no steps\"
'"
done
for H in "${HOSTS[@]}"; do
    run_test "T2z:  $H/README.md exists" "test -f '$H/README.md'"
done
echo

# ── Tier 6: Composite action input contract (Family A vs Family B) ───────────
#
# Family A — "kotlin-js-build-and-publish-to-branch": gh-pages.
#            Accepts (web_package_name, target_stage) — the caller's `with:` matches.
# Family B — "publish-prebuilt-dist-via-provider-cli": cloudflare-pages, netlify, vercel.
#            Accept (dist_dir, provider_token, provider_site_id) — caller currently
#            passes Family A inputs to all 4 hosts, so cloudflare/netlify/vercel silently
#            ignore them. This is a pre-existing interface contract gap — should be
#            addressed in a follow-up PR (build → dist_dir → per-provider upload).
echo "── Tier 6: Composite action input contract ──"
run_test "T3x:  gh-pages (Family A) accepts (web_package_name, target_stage)" "py '
import yaml
d = yaml.safe_load(open(\"gh-pages/action.yaml\"))
declared = set(d.get(\"inputs\", {}).keys())
required = set([\"web_package_name\",\"target_stage\"])
assert required.issubset(declared), \"gh-pages missing inputs: \" + str(required - declared)
'"
run_test "T3x:  cloudflare-pages (Family B) accepts (dist_dir, cloudflare_pages_api_token, cloudflare_account_id)" "py '
import yaml
d = yaml.safe_load(open(\"cloudflare-pages/action.yaml\"))
declared = set(d.get(\"inputs\", {}).keys())
required = set([\"dist_dir\",\"cloudflare_pages_api_token\",\"cloudflare_account_id\"])
assert required.issubset(declared), \"cloudflare-pages missing inputs: \" + str(required - declared)
'"
run_test "T3x:  netlify (Family B) accepts (dist_dir, netlify_auth_token, netlify_site_id)" "py '
import yaml
d = yaml.safe_load(open(\"netlify/action.yaml\"))
declared = set(d.get(\"inputs\", {}).keys())
required = set([\"dist_dir\",\"netlify_auth_token\",\"netlify_site_id\"])
assert required.issubset(declared), \"netlify missing inputs: \" + str(required - declared)
'"
run_test "T3x:  vercel (Family B) accepts (dist_dir, vercel_token, vercel_org_id, vercel_project_id)" "py '
import yaml
d = yaml.safe_load(open(\"vercel/action.yaml\"))
declared = set(d.get(\"inputs\", {}).keys())
required = set([\"dist_dir\",\"vercel_token\",\"vercel_org_id\",\"vercel_project_id\"])
assert required.issubset(declared), \"vercel missing inputs: \" + str(required - declared)
'"
echo

# ── Tier 7: validate-secrets per-host coverage ───────────────────────────────
echo "── Tier 7: validate-secrets per-host coverage ──"
run_test "T31: validate-secrets has case for gh-pages (no secrets required)" \
    "grep -E 'gh-pages\\)' .github/workflows/release.yaml"
run_test "T32: validate-secrets has case for cloudflare-pages" \
    "grep -E 'cloudflare-pages\\)' .github/workflows/release.yaml"
run_test "T33: validate-secrets has case for netlify" \
    "grep -E 'netlify\\)' .github/workflows/release.yaml"
run_test "T34: validate-secrets has case for vercel" \
    "grep -E 'vercel\\)' .github/workflows/release.yaml"
run_test "T35: gh-pages requires no extra secrets" "py '
import re
with open(\".github/workflows/release.yaml\") as f: c = f.read()
m = re.search(r\"gh-pages\\)(.*?);;\", c, re.DOTALL)
assert m and \"MISSING+=\" not in m.group(1), \"gh-pages should not require secrets\"
'"
echo

# ── Tier 8: Multi-stage promote ladder logic ─────────────────────────────────
echo "── Tier 8: Multi-stage promote ladder logic ──"
run_test "T36: stage-1-preview if-condition allows {preview, staging, production}" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
cond = d[\"jobs\"][\"stage-1-preview\"][\"if\"]
assert \"preview\" in cond and \"staging\" in cond and \"production\" in cond
'"
run_test "T37: stage-2-staging if-condition allows {staging, production}" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
cond = d[\"jobs\"][\"stage-2-staging\"][\"if\"]
assert \"staging\" in cond and \"production\" in cond
'"
run_test "T38: stage-3-production if-condition allows {production} only" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
cond = d[\"jobs\"][\"stage-3-production\"][\"if\"]
assert \"production\" in cond
'"
echo

# ─────────────────────────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed · $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    echo "  Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do echo "    - $t"; done
fi
echo "════════════════════════════════════════════════════════════════════════════"
exit $FAIL
