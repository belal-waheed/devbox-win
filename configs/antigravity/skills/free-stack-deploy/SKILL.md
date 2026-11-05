---
name: free-stack-deploy
description: Deploys a Python, ASP.NET Core, or Next.js full-stack project to a permanent, zero-credit-card free hosting stack (Render or MonsterASP.net or Cloudflare Workers + Neon Postgres + Upstash Redis/QStash). Use when the user asks to deploy, host, or "put this online for free" a full-stack app, or asks to set up free hosting, a free database, a Redis cache, or free cron/scheduled jobs.
---

# Free Stack Deploy

## Goal
Get a full-stack app (Python, ASP.NET Core, or Next.js) live on a permanent free hosting stack that never asks for a credit card — not even a "won't charge you" card. Add a shared Postgres database, Redis cache, and scheduled/cron jobs across all three stacks using the same two services (Neon + Upstash), so the setup stays consistent no matter which stack the project uses.

## Before you start — human-only steps, do not attempt to automate
Account creation, email verification, and connecting GitHub via OAuth cannot be done by an agent. Before doing anything else, confirm the user has already created accounts and generated API keys for the services this task needs (see "Accounts & keys needed" below). If a key is missing, stop and ask for it. Never invent, guess, or reuse a placeholder as if it were a real key.

## Step 1 — Detect the stack
Look at the repo for:
- `requirements.txt` / `pyproject.toml` / `manage.py` -> Python
- `*.csproj` / `Program.cs` / `appsettings.json` -> ASP.NET Core
- `next.config.js` / `next.config.ts` + a `"next"` dependency in `package.json` -> Next.js

If more than one matches, or none do, ask the user which stack this deploy is for. Don't guess silently.

## Step 2 — Target hosts (verified card-free — do not substitute)

| Stack | App host | Database | Cache | Cron / scheduled jobs |
|---|---|---|---|---|
| Python | Render (free web service) | Neon (Postgres) | Upstash Redis | Upstash QStash |
| ASP.NET Core | MonsterASP.net (free tier) | Neon (Postgres, via Npgsql) — or MonsterASP's included MSSQL if the user prefers | Upstash Redis (via REST API) | Upstash QStash |
| Next.js | Cloudflare Workers, via the OpenNext adapter (default) | Neon (Postgres) | Upstash Redis | Upstash QStash |

Never suggest a host with an expiring free trial, a "free credits" model, or any signup step that asks for a payment method — even one it claims not to charge. This also rules out Koyeb: its free tier can still prompt for a card during signup as a fraud check, so don't use it even though it's marketed as card-free.

**Why Cloudflare Workers over Vercel for Next.js:** Cloudflare's free Workers plan has no cold starts (V8 isolates, not sleeping containers), allows commercial use with no restriction, and now has mature Next.js support (App Router, Server Actions, ISR) through the official `@opennextjs/cloudflare` adapter. Vercel's Hobby plan is simpler to set up (zero config) and also has no cold starts, but its terms restrict it to personal, non-commercial projects. Use Vercel instead of Cloudflare only if the user explicitly says the project is personal/non-commercial and they want the simplest possible setup — otherwise default to Cloudflare Workers.

## Step 3 — Use these MCP servers if connected; otherwise fall back to the manual steps in Step 4

- **Neon MCP** — `https://mcp.neon.tech/mcp`, auth via `NEON_API_KEY`. Creates the Postgres project/branch and returns the connection string. Never run destructive SQL without explicit user confirmation.
- **Cloudflare MCP** — official, OAuth-based, covers the full Cloudflare API (Workers, KV, R2) through `search()` and `execute()` tools. Check current endpoints on Cloudflare docs. Use it to create the Worker, set up the KV namespace the ISR cache needs, and deploy. It is the default path for Next.js.
- **Vercel MCP** — `https://mcp.vercel.com`, browser OAuth (no key to store). Only relevant if the user picked the Vercel fallback path for Next.js (see Step 2). Use `deploy_to_vercel`. It cannot set or edit environment variables on an existing project — that stays a manual dashboard step.
- **Render MCP** — early access, auth via `RENDER_API_KEY`. Creates the web service and checks deploy status/logs for the Python stack.
- **Upstash MCP** — auth via `UPSTASH_EMAIL` + `UPSTASH_API_KEY`. Creates the Redis database and the QStash schedule.
- **GitHub MCP** (or plain git) — pushes the repo that Render/Cloudflare/Vercel deploy from.
- **MonsterASP.net has no MCP server and no public deploy API.** Generate the config files it needs (Step 4), then hand the user the manual publish steps. Don't try to script around this gap.

If a listed MCP server isn't connected in this environment, tell the user which one is missing and keep going with whatever you can still do — don't stall the whole task over one missing connector.

## Step 4 — Generate these files per stack

**Python**
- `render.yaml` or a start command pointing at the app's WSGI/ASGI entrypoint
- `.env.example` with `DATABASE_URL`, `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`, `QSTASH_TOKEN`
- A `/health` route if one doesn't exist — Render's free tier sleeps after 15 minutes idle, and a health check makes the wake-up predictable

**ASP.NET Core**
- `appsettings.Production.json` with placeholder connection string and Upstash keys (no real secrets committed)
- Confirm `Program.cs` reads the connection string and Upstash keys from configuration/environment variables, not hardcoded
- Only if the user explicitly wants full agent-driven deploys instead of MonsterASP's manual publish: offer a `Dockerfile` + Render web service as the automatable alternative. MonsterASP.net stays the default.

**Next.js — default path (Cloudflare Workers via OpenNext)**
- Add `@opennextjs/cloudflare` as a dev dependency
- `wrangler.toml` with `compatibility_flags = ["nodejs_compat"]`, a KV namespace binding for the ISR/revalidation cache, and (only if the app serves large files) an R2 bucket binding
- Set the build command to `npx opennextjs-cloudflare build`
- `.env.local.example` with `DATABASE_URL` (Neon, via the Neon serverless HTTP driver or Hyperdrive — Workers cannot open a raw TCP connection), `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`, `QSTASH_TOKEN`, `QSTASH_CURRENT_SIGNING_KEY`
- An API route (e.g. `app/api/cron/route.ts`) that QStash calls on schedule — verify the QStash signature on every request, never accept an unsigned one
- `next/image` optimization needs the Cloudflare Images add-on, which isn't free — default to `unoptimized: true` in `next.config` unless the user says they're fine paying for Cloudflare Images

**Next.js — fallback path (Vercel, personal/non-commercial only)**
- Same `.env.local.example` contents as above, no Cloudflare-specific files needed
- Flag clearly to the user that Vercel's Hobby plan forbids commercial use — confirm the project is genuinely personal before generating this path instead of the Cloudflare default

## Step 5 — Verification & Testing
After generating files and provisioning what the connected MCP servers allow, check deploy status/logs through the relevant MCP tool and report back plainly: active deployment status, the live URL, what still needs the user to do by hand (Step 4 manual pieces + account/key setup), and any error found in the logs.
Run test suites locally before triggering deploys:
```bash
npm test
# or: dotnet test / pytest
```

## Safety rules & Negative Constraints
- Never commit a real API key, connection string, or a `.env` file with live secrets — placeholders only in the repo; real values go in the host's dashboard or a local untracked `.env`.
- Never select a paid tier or attach a payment method on the user's behalf, even a $0-authorization one.
- If any step turns out to actually need a credit card, stop and tell the user before proceeding — do not quietly route around it with a different plan.

## Accounts & keys needed (user provides — never generate or fake these)
- GitHub account + personal access token (for MCP/git pushes)
- Render account + `RENDER_API_KEY` (Python stack)
- MonsterASP.net account (ASP.NET stack — no API key, dashboard/FTP/Web Deploy only)
- Cloudflare account + API token (Next.js stack, default path — used by the Cloudflare MCP server)
- Vercel account (Next.js stack, fallback path only — browser OAuth via Vercel MCP, no key to store)
- Neon account + `NEON_API_KEY` (all stacks)
- Upstash account + `UPSTASH_EMAIL` + `UPSTASH_API_KEY` (all stacks — covers both Redis and QStash)
