# AuditKaro — SEO Audit Web App

Web-based SEO audit tool. Enter a URL, get a comprehensive 0-100 scored audit in under 3 minutes.

**Price:** ₹9 per full audit (~$0.11)

## What It Does

7 audit dimensions, scored and benchmarked against your competitors:

1. **Technical SEO** — CWV via Lighthouse, mobile, security, speed, crawlability
2. **On-Page SEO** — titles, meta, headings, images, internal links, keywords
3. **Content Quality** — E-E-A-T, depth vs SERP competitors, readability, AI writing detection
4. **UX & Accessibility** — WCAG via axe-core, navigation, trust signals, cognitive load
5. **Conversion & CTA** — intent-CTA alignment, friction points, persuasion psychology
6. **AI Search Readiness** — bot access, BLUF, schema, entity SEO, citability
7. **AIO Simulation** — simulates whether Google's AI Overview would cite your page

## Tech Stack

- **Frontend:** Next.js 14 + Tailwind + shadcn/ui
- **Backend:** Vercel serverless + Railway (Playwright workers)
- **Database:** Supabase (PostgreSQL + Auth)
- **Payments:** Razorpay (UPI + cards)
- **Crawling:** Playwright (screenshots, video, JS rendering)
- **Performance:** Lighthouse (programmatic Node API)
- **Accessibility:** axe-core + Pa11y
- **LLM:** Claude API (Sonnet + Haiku) with prompt caching + batch API
- **Queue:** BullMQ + Upstash Redis

## Architecture

```
User enters URL
  → Playwright renders pages + captures screenshots
  → Programmatic tools measure everything measurable
  → SERP competitors fetched and analyzed
  → LLM judges qualitative dimensions with evidence
  → AIO simulation runs
  → Scored dashboard with annotated screenshots delivered
```

## Development

```bash
git clone https://github.com/shibanshu12/seo-audit-app.git
cd seo-audit-app
npm install
cp .env.local.example .env.local  # fill in your keys
npm run dev
```

## Docs

- [PRD.md](./PRD.md) — Full product requirements document
- [ARCHITECTURE.md](./ARCHITECTURE.md) — Technical architecture (coming soon)

## License

MIT
