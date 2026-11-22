#!/usr/bin/env ruby
# frozen_string_literal: true

# Security audit report generator (Issue #263).
#
# Rebuilds docs/security-audit/audity-security-report.md from the FINDINGS data
# below. Run with: `ruby docs/security-audit/generate_report.rb`
# Add `--html` to also write an A4 print-styled HTML wrapper.
#
# Palette (per the issue):
#   critical #B91C1C  high #EA580C  medium #D97706  low #2563EB  strong #059669

require "erb"
require "date"

OUT_DIR   = File.expand_path(__dir__)
MD_PATH   = File.join(OUT_DIR, "audity-security-report.md")
HTML_PATH = File.join(OUT_DIR, "audity-security-report.html")
AUDIT_DATE = "2026-11-21"

PALETTE = {
  "critical" => "#B91C1C", "high" => "#EA580C", "medium" => "#D97706",
  "low" => "#2563EB", "info" => "#6B7280", "strong" => "#059669"
}.freeze

# Each finding: id, severity, category, title, file, lines(array), snippet,
# why, impact, fix, conditions, issue(bool).
FINDINGS = [
  {
    id: "SEC-01", severity: "high", category: "IDOR / Broken Access Control",
    title: "DrillSkills API is unauthenticated and has no authorization",
    file: "beachvolleyballhub_api/app/controllers/api/v1/drill_skills_controller.rb",
    lines: ["1-49", "4", "6-36", "40-44"],
    snippet: <<~RUBY,
      class DrillSkillsController < ApplicationController
        before_action :set_drill_skill, only: [ :show, :update, :destroy ]
        def index
          @drill_skills = DrillSkill.includes(:drill, :skill).all   # every row, anonymous
        end
        def create
          @drill_skill = DrillSkill.new(drill_skill_params)          # no auth, no policy
        end
        # update / destroy: no auth, no policy
      end
    RUBY
    why: <<~MD,
      `Api::V1::ApplicationController` skips `require_authentication` (the JSON API is
      public by default); this controller adds only a `set_drill_skill` loader — no
      authentication, no Pundit `authorize`, no gate. The route `resources :drill_skills`
      (config/routes.rb:148) exposes `GET/POST/PATCH/PUT/DELETE /api/v1/drill_skills(/:id)`
      to the internet.
    MD
    impact: <<~MD,
      Anonymous integrity tampering of catalogue data: anyone can list, create, mutate
      and delete drill↔skill rows (detaching skills from drills across the catalogue).
    MD
    fix: <<~MD,
      Add `before_action :require_authentication`, gate writes on a content-creator
      concern (`require_content_creator!`) and `authorize` the affected Drill/Skill via
      `DrillPolicy`/`SkillPolicy`; restrict reads to published content or managers. If the
      endpoint is unused, remove `resources :drill_skills` from the routes.
    MD
    conditions: "None — live route, exploitable anonymously.", issue: true
  },
  {
    id: "SEC-02", severity: "medium", category: "Exposed Keys",
    title: "Google Maps Embed API key is shipped in every client bundle",
    file: "beachvolleyballhub/src/components/locations/LocationMap.tsx",
    lines: ["33", "37-45"],
    snippet: <<~JS,
      const apiKey = import.meta.env.VITE_GOOGLE_MAPS_EMBED_API_KEY?.trim();
      const url = new URL("https://www.google.com/maps/embed/v1/place");
      url.searchParams.set("key", apiKey); // baked into dist/ + android/ + ios/
    JS
    why: <<~MD,
      `VITE_*` variables are inlined into the client bundle at build time. The key
      `AIzaSy…75bTw` is present in the served web bundle (`dist/assets/*.js`) and in the
      Capacitor mobile bundles (`android/app/src/main/assets/public/assets/*.js`,
      `ios/App/App/public/assets/*.js`). Google Maps *Embed* keys are browser keys and are
      public by design, but only stay safe when restricted in GCP to the authorised HTTP
      referrers / app bundle IDs and to the "Maps Embed API" only.
    MD
    impact: <<~MD,
      If unrestricted, any third party can embed the key on their own site and drain the
      project's Maps quota and billable usage. The key ships with every app-store download.
    MD
    fix: <<~MD,
      In Google Cloud Console restrict the key to the production HTTP referrers
      (`https://beachvolleyballhub.com/*`, the Workers domain) plus the Android package
      name / SHA-1 and iOS bundle ID, and to the "Maps Embed API" only. Rotate the key and
      add a quota/budget alert. Keep it out of any committed mobile assets.
    MD
    conditions: "Browser key — exposure is inherent; risk depends on GCP restrictions.", issue: true
  },
  {
    id: "SEC-03", severity: "low", category: "IDOR / Broken Access Control",
    title: "AcceptInvitationsController#update resolves invitations by raw id (unrouted dead code)",
    file: "beachvolleyballhub_api/app/controllers/accept_invitations_controller.rb",
    lines: ["32-33", "60-72"],
    snippet: <<~RUBY,
      def update
        @invitation = AccountInvitation.find(params[:id])   # no token check
        @invitation.user.update!(password_digest: BCrypt::Password.create(params[:password]), ...)
    RUBY
    why: <<~MD,
      The action loads an `AccountInvitation` by numeric id and, on success, resets that
      user's password and logs them in, with no proof the caller holds the invitation token
      — a textbook account-takeover IDOR. It is **not exploitable today**: no
      `accept-invitation` route is mounted (verified with `rails routes`) and the code also
      references removed APIs (`is_verified`, `login`, `onboarding_path`).
    MD
    impact: "Latent only — if routed, any visitor could take over any account by guessing an invitation id.",
    fix: "Delete the dead controller/views, or resolve by `token_digest` (as `edit` does) before allowing any password change.",
    conditions: "Not routed — latent only.", issue: false
  },
  {
    id: "SEC-04", severity: "low", category: "Configuration / Deployment",
    title: "CORS allow-list appends localhost and private-IP origins unconditionally",
    file: "beachvolleyballhub_api/config/initializers/cors.rb",
    lines: ["12-16", "18-26"],
    snippet: <<~RUBY,
      if Rails.env.development?
        allowed_origins.concat([ "http://localhost:5174", "http://localhost:3001" ])
      end
      # ... but these are appended OUTSIDE the development guard:
      allowed_origins << "http://localhost:5174"
      allowed_origins << "http://192.168.1.25:5174"
      allowed_origins << "http://192.168.1.105:5174"   # + several more LAN IPs
    RUBY
    why: <<~MD,
      Development origins and hard-coded LAN IPs are appended to the allow-list regardless
      of `Rails.env`, so the production API accepts browser requests from `http://localhost`
      and specific private IPs. `credentials` is not enabled, so cross-origin cookies are
      not sent, which blunts the risk — but the production origin allow-list should be the
      deployed frontends only.
    MD
    impact: "Weakens the origin allow-list; exposes the API to requests originating from a victim's own localhost/LAN (e.g. a malicious local app).",
    fix: "Move the localhost/LAN entries inside the `Rails.env.development?` block and keep only real deployed origins (plus the Workers preview regex) in production.",
    conditions: "Requires the browser to issue a cross-origin request from a localhost/LAN origin.", issue: true
  },
  {
    id: "SEC-05", severity: "low", category: "Configuration / Deployment",
    title: "TLS enforcement and secure cookies depend on BEHIND_HTTPS_PROXY",
    file: "beachvolleyballhub_api/config/environments/production.rb",
    lines: ["29-31"],
    snippet: <<~RUBY,
      config.assume_ssl = ENV["BEHIND_HTTPS_PROXY"] == "true"
      config.force_ssl  = ENV["BEHIND_HTTPS_PROXY"] == "true"
    RUBY
    why: <<~MD,
      `force_ssl` (redirect + `secure` cookies) is enabled only when `BEHIND_HTTPS_PROXY`
      is exactly `"true"`. The session cookie is also written without an explicit `secure`
      flag (`cookies.signed.permanent[:session_id] = { httponly: true, same_site: :lax }`).
      If the env var is missing/misspelled in a deployment, cookies can travel over plain
      HTTP and no HTTP→HTTPS redirect happens.
    MD
    impact: "Session confidentiality could be undermined by a misconfiguration (cookie sent over HTTP, no HSTS/redirect).",
    fix: "Set `config.force_ssl = true` unconditionally in production and add `secure: true` to the session cookie (or rely on a documented, validated deploy profile that fails fast when the proxy flag is absent).",
    conditions: "Only exploitable if BEHIND_HTTPS_PROXY is unset in production.", issue: true
  },


  {
    id: "SEC-06", severity: "low", category: "XSS (defense-in-depth)",
    title: "Bearer auth token persisted in localStorage",
    file: "beachvolleyballhub/src/api.ts",
    lines: ["56-69", "184-186"],
    snippet: <<~JS,
      const TOKEN_KEY = "bvb_api_token";
      export function setToken(token) { if (token) localStorage.setItem(TOKEN_KEY, token); }
      // request(): if (token) headers["Authorization"] = `Bearer ${token}`;
    JS
    why: <<~MD,
      The cross-origin API bearer token is stored in `localStorage`, which is readable by
      any JavaScript running on the origin. There is currently **no verified XSS sink** (see
      the strong points), so this is not directly exploitable — but it removes the
      HttpOnly-cookie safety net if a sink is ever introduced (a dependency, a future
      `dangerouslySetInnerHTML`, a poisoned third-party script).
    MD
    impact: "In combination with any future XSS, the bearer token is exfiltratable in one line, enabling full account takeover.",
    fix: "Prefer an HttpOnly, Secure, SameSite cookie for the session (the backend already sets one) and keep bearer tokens out of web storage, or shorten token lifetime and bind tokens to a rotating refresh flow.",
    conditions: "Defense-in-depth — no current XSS sink.", issue: false
  },
  {
    id: "SEC-07", severity: "low", category: "Tenant / Owner Isolation",
    title: "Server-rendered Skills HTML view exposes non-published skills",
    file: "beachvolleyballhub_api/app/controllers/skills_controller.rb",
    lines: ["4-14"],
    snippet: <<~RUBY,
      def index
        @skills = Skill.includes(:discipline).order(:title)   # no published/shared filter
      end
      def show
        @skill = Skill...find_by(slug: params[:id])
        @related_drills = @skill.drills...order(:title)       # no visibility check
      end
    RUBY
    why: <<~MD,
      The API `SkillPolicy#show?` restricts skills to `published_and_shared? || manager?`,
      but this legacy server-rendered controller (route `get "skills"`, `get "skills/:id"`)
      lists/serves every skill, including drafts, to anonymous visitors. The sibling
      `drills_controller` *does* apply the published+shared gate, so the two differ.
    MD
    impact: "Low: unpublished catalogue metadata (skill titles/descriptions and related drill titles) is readable anonymously via the HTML routes.",
    fix: "Apply `Skill.published_and_shared` (and the same visibility predicate used by `SkillPolicy`) in the HTML controller, or retire the legacy HTML routes if the SPA is the only product surface.",
    conditions: "HTML routes only; metadata exposure, no secrets.", issue: true
  },
  {
    id: "SEC-08", severity: "low", category: "Tenant / Owner Isolation",
    title: "Groups search does not escape SQL LIKE wildcards",
    file: "beachvolleyballhub_api/app/controllers/api/v1/groups_controller.rb",
    lines: ["41-44"],
    snippet: <<~'RUBY',
      if params[:q].present?
        term = "%#{params[:q]}%"
        groups = groups.where("groups.name ILIKE :t OR groups.description ILIKE :t", t: term)
      end
    RUBY
    why: <<~MD,
      The value is bound (so it is **not** SQL injection), but user-supplied `%` and `_`
      are not escaped with `sanitize_sql_like`, unlike `AccountsController#search` and
      `AnalysesController#index`. A query of `%%%%` forces a full-scan LIKE and arbitrary
      wildcards change matching semantics.
    MD
    impact: "Low: wildcard pattern injection (behavioural noise / minor DoS on large tables) within the caller's already-scoped group set.",
    fix: "Use `ActiveRecord::Base.sanitize_sql_like(params[:q])` before wrapping in `%…%`, matching the other controllers.",
    conditions: "Authenticated caller; scoped to groups they can already see.", issue: false
  },
  {
    id: "SEC-09", severity: "info", category: "Configuration / Deployment",
    title: "Private test-access gate is open when TEST_ACCESS_PASSWORD is unset",
    file: "beachvolleyballhub_api/app/controllers/concerns/test_access.rb",
    lines: ["9-11", "30-31"],
    snippet: <<~RUBY,
      # When TEST_ACCESS_PASSWORD is unset the gate is open (disabled) so local dev and CI are unaffected.
      def require_test_access
        return unless TestAccessToken.enabled?   # enabled? == TEST_ACCESS_PASSWORD present
      end
    RUBY
    why: <<~MD,
      This extra gate is intentionally open when the password is unset (local/CI). It is
      not the primary authentication (user auth still applies), but a production deployment
      that forgets the variable silently loses this layer.
    MD
    impact: "Informational: reduces one defense layer if misconfigured in production.",
    fix: "Document TEST_ACCESS_PASSWORD as an explicit production deploy requirement; optionally log a boot warning when Rails.env.production? and it is unset.",
    conditions: "Deployment configuration only.", issue: false
  },
].freeze

# Verified controls — the "strong points" section, with evidence.
STRONG_POINTS = [
  ["JSON API is public-by-default but every sensitive controller re-adds `require_authentication` (e.g. accounts, notifications, preferences, billing base, claims).", "app/controllers/api/v1/application_controller.rb:12"],
  ["Pundit is installed app-wide; denials render 404 for `show?` (no existence disclosure) and 401/403 otherwise via one handler.", "app/controllers/application_controller.rb:19,32-43"],
  ["Account reads are gated by `can_manage_account?` / `can_view_account?`; contact fields only returned to managers.", "app/controllers/api/v1/accounts_controller.rb:72-97,10"],
  ["Notifications are hard-scoped to `current_account.notifications` — no id reaches another account.", "app/controllers/api/v1/notifications_controller.rb:56,19-45"],
  ["Assessment listing uses `Assessment.visible_to(Current.user)` and show returns 404 for hidden rows.", "app/controllers/api/v1/assessments_controller.rb:56-57,83-84"],
  ["Analyses use `policy_scope(Analysis)` + `authorize` on every mutating action; children are parent-scoped.", "app/controllers/api/v1/analyses_controller.rb:10,27-73"],
  ["Organisation public read returns every permission flag `false` for anonymous callers; memberships expose only display_name/role/status (no contact data).", "app/controllers/api/v1/organisations_controller.rb:886-915; app/models/organisation_membership.rb:166"],
  ["Admin surface is uniformly gated by `authorize_admin!` (AdminAreaPolicy, real-user based).", "app/controllers/api/v1/admin/*.rb"],
  ["Stripe webhook verifies the signature against `request.raw_post` before processing — signature is the authentication.", "app/controllers/api/v1/webhooks/stripe_controller.rb:32-37"],
  ["Password reset and signup use token-based lookup + Turnstile + rate limiting; signup is transactional and email-verification gated.", "app/controllers/api/v1/passwords_controller.rb:21; registrations_controller.rb:6-33"],
  ["No XSS sinks in the SPA: no `dangerouslySetInnerHTML`; the one `innerHTML` assignment is static markup; contact mailer relies on auto-escaping ERB.", "src/main.tsx:76; app/views/contact_message_mailer/notification.html.erb:16-18"],
  ["Backend search endpoints escape LIKE wildcards with `sanitize_sql_like` (accounts, analyses, player_claims).", "app/controllers/api/v1/accounts_controller.rb:21; analyses_controller.rb:17"],
  ["No hard-coded server secrets in `app/`, `lib/`, `config/`; `.env*`, `.kamal/secrets` hold no raw credentials; `config/master.key` git-ignored.", "repo-wide grep 2026-11-21"],
  ["Contact form is layered: honeypot, Turnstile, validation, persistence, then async delivery — and returns a minimal, uniform response.", "app/controllers/api/v1/contact_messages_controller.rb:36-107"]
].freeze

CATEGORY_BLURB = {
  "Tenant / Owner Isolation" => "List/search/aggregate queries must be constrained to the caller's account/organisation. Mechanism here: Pundit scopes + `Current` + account-scoped queries.",
  "Permissions in the Browser" => "Frontend hides UI by role; the server must enforce the same role on every write. Mechanism here: Pundit policies + `ContentAuthorization` concerns.",
  "IDOR / Broken Access Control" => "Object lookup by id must verify ownership/tenancy. Mechanism here: `authorize`, nested scopes, owner checks.",
  "Exposed Keys" => "Keys/tokens/passwords embedded in source, configs, CI, bundles, or committed build artifacts.",
  "XSS (defense-in-depth)" => "Unescaped user input reaching HTML/e-mail. Frontend sinks and backend templates.",
  "Configuration / Deployment" => "CORS, TLS/cookies and feature gates that are environment dependent."
}.freeze

# Remediation status after the fix pass (2026-11-21). Keyed by finding id.
# status: resolved | mitigated | accepted-risk
REMEDIATION = {
  "SEC-01" => ["resolved",   "Writes now require auth + `require_content_creator!` + `authorize drill, :update?`; anonymous writes return 401 (tests added)."],
  "SEC-02" => ["mitigated",  "Client already degrades without the key; added `KEY_RESTRICTIONS.md` + `.env.example` hardening note. GCP restriction/rotation is an ops sign-off."],
  "SEC-03" => ["resolved",   "Deleted the unrouted `AcceptInvitationsController`."],
  "SEC-04" => ["resolved",   "localhost/LAN origins moved inside the `Rails.env.development?` guard (LAN via `DEV_CORS_ORIGINS`)."],
  "SEC-05" => ["resolved",   "`force_ssl = true` unconditionally in production (+ `/up` excluded) and session cookie sets `secure: true` in production."],
  "SEC-06" => ["mitigated",  "Bearer TTL shortened/parametrised (`API_SESSION_TTL_DAYS`, default 7) and trade-off documented; HttpOnly-cookie migration scheduled."],
  "SEC-07" => ["resolved",   "Legacy Skills HTML index/show now use `published_and_shared` (tests added)."],
  "SEC-08" => ["resolved",   "Groups search escapes LIKE wildcards with `sanitize_sql_like` (test added)."],
  "SEC-09" => ["mitigated",  "Production boot warning when `TEST_ACCESS_PASSWORD` is unset."]
}.freeze



# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------
SEV_ORDER = %w[critical high medium low info].freeze
SEV_LABEL = { "critical" => "Critical", "high" => "High", "medium" => "Medium",
              "low" => "Low", "info" => "Info" }.freeze

def sev_counts
  h = Hash.new(0)
  FINDINGS.each { |f| h[f[:severity]] += 1 }
  h
end

def cat_counts
  h = Hash.new(0)
  FINDINGS.each { |f| h[f[:category]] += 1 }
  h
end

def chip(sev)
  "<span style=\"background:#{PALETTE[sev]};color:#fff;padding:1px 8px;border-radius:10px;font-size:12px;font-weight:600\">#{SEV_LABEL[sev]}</span>"
end

# ---------------------------------------------------------------------------
# Markdown builder
# ---------------------------------------------------------------------------
md = +""
md << <<~MD
  # Relatório de Auditoria de Segurança

  > **Security Audit Report** — generated #{AUDIT_DATE}

  **Scope:** `romalopes/beachvolleyballhub_api` (Rails 8.1 API) and the consuming
  `beachvolleyballhub` React/Vite SPA (including Capacitor Android/iOS bundles).

  **Methodology note.** The five categories from the audit brief were mapped to this
  stack: tenant isolation → Pundit scopes + `Current` + account-scoped queries;
  browser permissions → controller concerns (`ContentAuthorization`) vs React role
  gates; IDOR → every controller handler that loads a record by id; exposed keys →
  `app/`, `lib/`, `config/`, `.env*`, `.kamal/secrets`, CI, and the built client
  bundles; XSS → React sinks and Rails mailer/HTML templates. Findings below are
  **verified in the code**; each cites `file:line`. Categories that do not apply are
  stated rather than filled.

  ---
MD

md << "\n## Executive summary\n\n"
c = sev_counts
md << "| Severity | Count |\n|---|---|\n"
SEV_ORDER.each { |s| md << "| #{chip(s)} | #{c[s]} |\n" }
md << "| **Total** | **#{FINDINGS.size}** |\n\n"

# Mermaid pie (rendered on GitHub)
md << "```mermaid\npie showData\n"
md << "    title Findings by severity\n"
SEV_ORDER.each do |s|
  next if c[s].zero?
  md << "    \"#{SEV_LABEL[s]}\" : #{c[s]}\n"
end
md << "```\n\n"

md << "```mermaid\n%%{init: {'theme':'base','themeVariables':{'primaryColor':'#2563EB'}}}%%\n"
md << "xychart-beta horizontal\n"
md << "    title \"Findings by category\"\n"
cats = cat_counts
labels = cats.keys
md << "    x-axis [#{labels.map { |l| "\"#{l}\"" }.join(', ')}]\n"
md << "    y-axis \"count\" 0 --> #{[cats.values.max || 1, 1].max + 1}\n"
md << "    bar [#{labels.map { |l| cats[l] }.join(', ')}]\n"
md << "```\n\n"

md << <<~MD
  **Severity legend:** #{chip('critical')} · #{chip('high')} · #{chip('medium')} · #{chip('low')} · #{chip('info')}
MD

File.write(MD_PATH, md)
puts "wrote #{MD_PATH} (part 1: cover + summary)"


md << "\n## Remediation status (fix pass #{AUDIT_DATE})\n\n"
md << "| ID | Status | Change |\n|---|---|---|\n"
FINDINGS.each do |f|
  status, note = REMEDIATION.fetch(f[:id], ["open", "—"])
  badge = case status
          when "resolved" then "✅ resolved"
          when "mitigated" then "🟡 mitigated"
          when "accepted-risk" then "⚪ accepted-risk"
          else "🔴 open"
          end
  md << "| #{f[:id]} | #{badge} | #{note} |\n"
end
md << "\n"


md << "\n## Strong points (what is protected, with evidence)\n\n"
STRONG_POINTS.each { |(text, ev)| md << "- ✅ #{text}  \n  <sub>`#{ev}`</sub>\n" }

md << "\n## Weak points (central risks)\n\n"
md << "- ❌ **Unauthenticated write surface (SEC-01):** the `drill_skills` endpoint is reachable anonymously and lets anyone mutate catalogue joins.\n"
md << "- ❌ **Public browser key without proven GCP restrictions (SEC-02):** the Maps Embed key ships in every client bundle.\n"
md << "- ⚠️ **Environment-dependent hardening (SEC-04, SEC-05, SEC-09):** CORS localhost entries, `force_ssl`, the secure cookie flag and the test-access gate all key off env vars that a misconfigured deploy can leave open.\n"

md << "\n## Detailed findings\n\n"
md << "| ID | Severity | Category | File:line |\n|---|---|---|---|\n"
FINDINGS.each do |f|
  md << "| #{f[:id]} | #{chip(f[:severity])} | #{f[:category]} | `#{f[:file].split('/').last}:#{f[:lines].first}` |\n"
end
md << "\n"

FINDINGS.each do |f|
  md << "### #{f[:id]} — #{chip(f[:severity])} — #{f[:title]}\n\n"
  md << "- **Category:** #{f[:category]}\n"
  md << "- **Location:** `#{f[:file]}` lines #{f[:lines].join(', ')}\n"
  md << "- **Exploitability conditions:** #{f[:conditions]}\n\n"
  md << "**Evidence**\n\n```\n#{f[:snippet].rstrip}\n```\n\n"
  md << "**Why it is exploitable / risky**\n\n#{f[:why].rstrip}\n\n"
  md << "**Impact**\n\n#{f[:impact].rstrip}\n\n"
  md << "**Suggested fix**\n\n#{f[:fix].rstrip}\n\n"
end

md << <<~MD
  ## Prioritized recommendations

  **P1 — Immediate**
  1. **SEC-01:** authenticate + authorize `DrillSkillsController` (or remove the route). This is the only anonymously reachable write surface.

  **P2 — This sprint**
  2. **SEC-02:** confirm and enforce Google Maps Embed key restrictions (HTTP referrer + Android/iOS bundle id + API restriction), rotating the key and adding a quota alert.
  3. **SEC-05:** make `force_ssl` unconditional in production and set `secure: true` on the session cookie.
  4. **SEC-04:** move localhost/LAN origins inside the development-only block.

  **P3 — Hardening**
  5. **SEC-07:** apply the published/visibility predicate to the legacy Skills HTML controller (or retire it).
  6. **SEC-08:** escape LIKE wildcards in `GroupsController#search`.
  7. **SEC-06:** move the bearer token off `localStorage` toward the HttpOnly session cookie.
  8. **SEC-09:** document `TEST_ACCESS_PASSWORD` as a required production variable.
MD

File.write(MD_PATH, md)
puts "wrote #{MD_PATH} (part 2: controls + findings + recommendations)"


# ---------------------------------------------------------------------------
# GitHub issues (copy-paste blocks) — one per issue:true finding
# ---------------------------------------------------------------------------
md << "\n---\n\n## ISSUES PARA O GITHUB\n\n"
issue_findings = FINDINGS.select { |f| f[:issue] }
issue_findings.each_with_index do |f, idx|
  n = idx + 1
  md << "--- ISSUE #{n} ---\n\n"
  md << "**Título:** `[Segurança] #{f[:title]}`\n\n"
  md << "**Labels:** `security`, `severity:#{f[:severity]}`\n\n"
  md << "### Descrição do problema\n\n#{f[:why].rstrip}\n\n"
  md << "### Evidência\n\n`#{f[:file]}` — linhas #{f[:lines].join(', ')}\n\n```\n#{f[:snippet].rstrip}\n```\n\n"
  md << "### Impacto\n\n#{f[:impact].rstrip}\n\n"
  md << "### Sugestão de correção\n\n#{f[:fix].rstrip}\n\n"
  md << "### Critérios de aceite\n\n"
  md << "- [ ] A falha descrita não é mais reproduzível.\n"
  md << "- [ ] Teste automatizado cobre o cenário (positivo e negativo).\n"
  md << "- [ ] Revisão de código confirma que a correção não abre nova superfície.\n\n"
  md << "--- FIM ISSUE #{n} ---\n\n"
end

File.write(MD_PATH, md)
puts "wrote #{MD_PATH} (#{FINDINGS.size} findings, #{issue_findings.size} issue blocks)"

# ---------------------------------------------------------------------------
# Optional A4 print-styled HTML
# ---------------------------------------------------------------------------
if ARGV.include?("--html")
  body = ERB::Util.html_escape(md)
  html = <<~HTML
    <!doctype html><html lang="en"><head><meta charset="utf-8">
    <title>Relatório de Auditoria de Segurança</title>
    <style>
      @page { size: A4; margin: 2cm;
        @top-center { content: "Relatório de Auditoria de Segurança"; font-size: 9pt; color:#6B7280; }
        @bottom-center { content: "Page " counter(page) " of " counter(pages); font-size: 9pt; color:#6B7280; } }
      body { font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; line-height:1.5; color:#1F2937; }
      h1,h2,h3 { color:#111827; } table { border-collapse:collapse; width:100%; }
      td,th { border:1px solid #E5E7EB; padding:6px 8px; font-size:10pt; }
      pre { background:#F3F4F6; padding:10px; border-radius:6px; font-size:9pt; white-space:pre-wrap; }
      code { background:#F3F4F6; padding:1px 4px; border-radius:4px; }
    </style></head><body><pre style="background:none;white-space:pre-wrap">#{body}</pre></body></html>
  HTML
  File.write(HTML_PATH, html)
  puts "wrote #{HTML_PATH} (open in a browser -> Print to PDF)"
end

