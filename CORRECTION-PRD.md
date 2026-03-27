# CORRECTION PRD — LLM Strategy & Quality Revision

**Purpose:** This document corrects critical architectural decisions in the original PRD. If you're building or revising the SEO audit app, apply these changes. They override the original PRD where they conflict.

**Context:** The original PRD over-optimized for cost and under-invested in LLM quality. The product's value comes from AI-powered qualitative analysis, not programmatic checks. Programmatic tools are infrastructure. The LLM output is the product. This revision rebalances accordingly.

---

## CORRECTION 1: Default LLM Is DeepSeek V3.2, Not Claude

**Primary LLM: DeepSeek V3.2** ($0.28/M input, $0.42/M output, cached: $0.028/M input)
- Use for ALL analytical work: E-E-A-T, content depth, conversion psychology, semantic completeness, citability, fan-out generation, persona analysis
- 10x cheaper than Sonnet means 10x more analysis for the same budget

**Classification LLM: Gemini 2.0 Flash-Lite** ($0.075/M input, $0.30/M output)
- Simple classification only: site type, page intent, CTA categorization

**Premium LLM (₹29 tier only): Claude Sonnet 4.6** ($3/M input, $15/M output)
- ONLY for premium "deep audit" tier, NOT used in ₹9 standard audit

```typescript
// Model routing config
const MODEL_CONFIG = {
  classify: { provider: 'gemini', model: 'gemini-2.0-flash-lite' },
  analyze: { provider: 'deepseek', model: 'deepseek-chat' },
  premium: { provider: 'anthropic', model: 'claude-sonnet-4-6-20250514' },
};
```

---

## CORRECTION 2: 10 Deep LLM Calls, Not 5 Shallow Ones

| # | Call | Model | Purpose |
|---|------|-------|---------|
| 1 | Site Classification | Gemini | Classify site type, industry, persona |
| 2 | Fan-Out Questions | DeepSeek | Generate sub-queries from SERP data |
| 3 | E-E-A-T Deep (homepage) | DeepSeek | Per-page scoring with evidence + competitor comparison |
| 4 | E-E-A-T Deep (landing page) | DeepSeek | Same for highest-traffic page |
| 5 | Content Depth | DeepSeek | Coverage matrix judgment per fan-out question |
| 6 | Conversion Walk-Through | DeepSeek | Narrative: walk site as real customer |
| 7 | AIO Simulation Pass 1 | DeepSeek | Simulate AI Overview, cite sources |
| 8 | AIO Simulation Pass 2 | DeepSeek | Critique own simulation, find minimum edit to win citation |
| 9 | Strategic Synthesis | DeepSeek | One highest-impact fix + contrarian take |
| 10 | Persona Narrative | DeepSeek | Who site speaks to vs who it should |

Cost: ~$0.035 = ₹2.94 (less than original, more analysis)

---

## CORRECTION 3: Two-Pass AIO Simulation

Pass 1: Simulate (generate AI Overview, cite sources, explain why)
Pass 2: Critique (challenge own reasoning, find bias, specify minimum edit for target page to win citation)

The critique pass is the highest-value output in the entire audit.

---

## CORRECTION 4: Conversion Is Narrative, Not Checklist

Old: "CTA above fold: yes. Social proof: present. Score: 7/10."
New: "Your page assumes I know what a CRM is, but I searched 'best CRM for small business.' Your competitor opens with pricing. You open with 'Welcome to the future.' I'd leave in 8 seconds."

---

## CORRECTION 5: Pricing Tiers

| Tier | Price | LLM | Profit |
|------|-------|-----|--------|
| Free | ₹0 | None | - |
| Standard | ₹9 | DeepSeek (10 calls) | ₹5.73 (64%) |
| Premium | ₹29 | DeepSeek + Sonnet (13 calls) | ₹15.65 (54%) |
| Bulk 10 | ₹79 | DeepSeek (10 calls each) | ~₹50 |

---

## CORRECTION 6: Prompt Caching

System prompts (rubrics, instructions) identical across all audits. DeepSeek caches these at 90% discount. Structure every call as: large cached system prompt + small variable user message.

---

## CORRECTION 7: Report Style

Every section: What is this? (plain language) → Why it matters (revenue impact) → Your score → What we found (evidence) → Vs competitors → The one fix that matters.

Write for founders who've never heard of E-E-A-T, not SEO professionals.

---

## CORRECTION 8: Multi-LLM Consensus (Premium Only)

₹29 tier runs E-E-A-T through DeepSeek + Gemini + Sonnet simultaneously. When they disagree by >15 points, that's itself a valuable signal explained in the report.

---

*Where this document conflicts with PRD.md, this document takes precedence.*
