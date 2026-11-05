---
name: defuddle
description: Distill raw web pages, documentation, PRDs, and URLs into clean, token-efficient Markdown with structured metadata.
---

# Defuddle: Web & Document Markdown Distillation Protocol

Defuddle transforms noisy, cluttered web pages, documentation portals, API specs, and PRDs into dense, token-efficient, structure-preserving Markdown. It eliminates navigational cruft, ads, cookie banners, and layout boilerplate while retaining high-fidelity technical contracts, code examples, schemas, and architectural invariants.

```
[Raw URL / HTML / PRD / Web Page]
               │
               ▼
   [1. Ingestion & Pre-Filter]   ──► Extract raw semantic main body
               │
               ▼
   [2. Clutter & Boilerplate Strip] ──► Remove navbars, footers, cookie banners, ads
               │
               ▼
   [3. Technical Density Boost]  ──► Preserve API signatures, tables, code, diagrams
               │
               ▼
   [4. Structured Frontmatter]   ──► Synthesize YAML metadata & token-optimized Markdown
```

---

## 1. Core Operating Principles

1. **Information Density Over Verbatim Copy:** Maximize useful technical tokens per kilobyte. Strip decorative prose, marketing jargon, and navigational filler.
2. **Preserve Exact Technical Invariants:** Never alter, truncate, or paraphrase code snippets, API signatures, type definitions, environment variable names, error codes, or version constraints.
3. **Structured Frontmatter Standard:** Every distilled document begins with a clean YAML metadata block identifying the origin, retrieval timestamp, author, and executive summary.
4. **Token Hygiene:** Strip base64 inline images, tracking pixels, nested styling divs, decorative SVGs, and repetitive social links.
5. **Portability:** Never leave machine-specific path references in extracted artifacts. Store distilled output in project scratch spaces (e.g., `.scratch/defuddle/<slug>.md`) or deliver directly to the agent context.

---

## 2. Clutter Stripping Rules

When processing HTML or web content, eliminate the following non-semantic elements:

| Category | Elements to Strip |
|---|---|
| **Navigation & Header** | `<header>`, `<nav>`, breadcrumb menus, hamburger buttons, mobile drawer navigations, search modals |
| **Footer & Disclaimers** | `<footer>`, copyright notices, terms of service, privacy policy links, back-to-top buttons |
| **Monetization & Ads** | Sponsored blocks, banner ads, newsletter signups, affiliate disclosures, promo banners |
| **Compliance & Tracking** | GDPR/cookie consent modals, tracking iframes, analytics scripts, social share buttons |
| **Ancillary Content** | "Related articles", "You might also like", sidebars, author bios (move to frontmatter), comment threads |
| **Decorative Markup** | Icon SVGs, inline styling attributes, presentational wrappers, empty spacing spans |

---

## 3. Distillation Workflow

### Phase 1: Semantic Extraction
- Locate the main article container (`<main>`, `<article>`, `#content`, or primary markdown body).
- Retain the heading hierarchy (`#`, `##`, `###`) to preserve logical section nesting.
- If handling raw web scraping via browser automation or cURL, extract `document.querySelector('main') || document.body`.

### Phase 2: Technical Preservation
- **Code Blocks:** Keep exact syntax highlighting tags (e.g., ````typescript ... ````, ````python ... ````).
- **Tables:** Preserve parameter tables, status codes, and configuration matrices in clean Markdown table format.
- **Lists:** Preserve ordered step sequences and unordered prerequisite lists.
- **Diagrams:** Convert image-based sequence or architecture diagrams into standard Mermaid or compact ASCII diagrams when possible.

### Phase 3: Token Compression & Normalization
- Strip redundant whitespace, trailing spaces, and excessive line breaks (maximum two consecutive newlines).
- Flatten deeply nested list items where indentation adds zero semantic meaning.
- Convert verbose UI narrative ("Click the settings button located in the top-right corner...") into concise imperative steps ("Navigate to Settings").
- Remove repeated boilerplate headers (e.g., "Table of Contents", "Introduction to This Guide").

### Phase 4: Output Synthesis
Synthesize the document into `.scratch/defuddle/<kebab-cased-slug>.md` using the standard layout below.

---

## 4. Standard Distillation Output Layout

Every Defuddle document must follow this template:

```markdown
---
title: "[Document Title]"
source_url: "[URL or Document Path]"
retrieved_date: YYYY-MM-DD
author: "[Author or Organization]"
topics: [topic1, topic2, topic3]
summary: "[1-3 sentence dense technical abstract of the document]"
---

# [Document Title]

## Overview
Concise summary of the core concepts, architecture, or purpose.

## Prerequisites & Constraints
- Dependency versions, permissions, runtime requirements.

## Core API / Specifications
Exact signatures, schemas, endpoints, and types:

```typescript
export interface TargetContract {
  id: string;
  payload: Record<string, unknown>;
  timeoutMs: number;
}
```

## Configuration & Parameters
| Parameter | Type | Required | Description | Default |
|---|---|---|---|---|
| `endpoint` | string | Yes | Target gateway URL | None |
| `maxRetries` | number | No | Exponential backoff attempts | `3` |

## Implementation Steps & Patterns
1. **Step 1:** Concrete action and code implementation.
2. **Step 2:** Boundary validation and error handling.

## Known Caveats & Error Codes
- **ERR_01:** Failure condition, trigger, and concrete remediation.
```

---

## 5. Specialized Formats

### API Documentation Portals (Swagger / OpenAPI / GraphQL)
- Discard visual Swagger UI layout.
- Synthesize directly to: HTTP Method, Endpoint Path, Headers, Request Body Schema, Response Schemas (200, 400, 500), and cURL/Fetch example.

### Technical PRDs & RFCs
- Extract: Problem Statement, User Stories, System Architecture, Boundary Interfaces, and Non-Goals.
- Discard: Stakeholder meeting notes, executive summaries written for non-technical audiences, and unrefined brainstorm logs.

### Vendor SDK Quickstarts
- Strip onboarding sales pitches and GUI console tutorials.
- Keep only: SDK package installation commands, authentication setup, and production client instantiation code.

---

## 6. Verification & Quality Gates

Before saving or passing distilled content to consuming agents:
- [ ] **Frontmatter Complete:** Valid YAML frontmatter with `title:`, `source_url:`, `retrieved_date:`, and `summary:`.
- [ ] **Zero Navigation Clutter:** No leftover cookie notices, header links, or footer legalese.
- [ ] **Exact Code Preservation:** Code blocks have correct language tags and are unaltered.
- [ ] **Token Efficiency:** Raw character count reduced by 40-70% compared to source page while retaining 100% of technical specifications.
- [ ] **Zero Local Path Leaks:** No personal filesystem paths in distilled artifacts.
