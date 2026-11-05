---
name: microlink-metadata
description: Production workflows and patterns for Microlink API integration (metadata extraction, link previews, headless page screenshots, color palette analysis, PDF generation, and Unavatar avatar resolution). Use when scraping anti-bot protected sites, generating visual bookmark covers, extracting OpenGraph/Twitter cards, or capturing automated web screenshots without managing browser infrastructure.
---

# Microlink Metadata & Headless Visual Engine

Microlink provides a high-reliability cloud browser engine that handles anti-bot challenges (Cloudflare, Akamai, Datadome), extracts normalized metadata, and captures full-page visual screenshots via simple REST endpoints.

---

## 1. Quick Reference & Core Endpoints

### A. Metadata Extraction (`/metadata`)
Extracts Open Graph, Twitter Cards, Schema.org JSON-LD, and article synopsis:
```bash
curl -s "https://api.microlink.io?url=https://github.com/facebook/react"
```

### B. High-Resolution Visual Screenshot (`screenshot=true`)
Captures a rendered 2560x1600 viewport screenshot of any web page:
```bash
curl -s "https://api.microlink.io?url=https://news.ycombinator.com&screenshot=true"
```
Response contains `data.screenshot.url` with permanent CDN hosting.

### C. Profile & Domain Avatars (Unavatar)
Resolves user and brand logos across Twitter, GitHub, YouTube, Telegram, and Gravatar:
```bash
# GitHub User Avatar
https://unavatar.io/github/facebook

# Twitter User Avatar
https://unavatar.io/x/levelsio

# Domain Favicon (High-Res 128px)
https://unavatar.io/cloudflare.com
```

---

## 2. Production TypeScript / Node.js Implementation

```typescript
export interface MicrolinkMetadataResult {
  title: string;
  description: string;
  image: string;
  logo: string;
  publisher: string;
  author: string;
  date: string;
}

export async function fetchMicrolinkMetadata(
  targetUrl: string,
  apiKey?: string
): Promise<MicrolinkMetadataResult | null> {
  const headers: Record<string, string> = {
    'User-Agent': 'MarkbelMetadataClient/2.1',
  };
  if (apiKey) {
    headers['x-api-key'] = apiKey;
  }

  try {
    const encoded = encodeURIComponent(targetUrl);
    const res = await fetch(`https://api.microlink.io?url=${encoded}&palette=true`, {
      headers,
      signal: AbortSignal.timeout(4500),
    });

    if (!res.ok) return null;

    const body: any = await res.json();
    if (body.status !== 'success' || !body.data) return null;

    const data = body.data;
    let imageUrl = data.image?.url || '';

    if (!imageUrl) {
      const shotRes = await fetch(`https://api.microlink.io?url=${encoded}&screenshot=true&meta=false`, {
        headers,
        signal: AbortSignal.timeout(4500),
      });
      if (shotRes.ok) {
        const shotBody: any = await shotRes.json();
        imageUrl = shotBody.data?.screenshot?.url || '';
      }
    }

    return {
      title: data.title || '',
      description: data.description || '',
      image: imageUrl,
      logo: data.logo?.url || '',
      publisher: data.publisher || '',
      author: data.author || '',
      date: data.date || '',
    };
  } catch (err) {
    console.warn('[Microlink Fetch Warning]:', err);
    return null;
  }
}
```

---

## 3. Best Practices & Guardrails

1. **Strict SSRF Verification**: Always validate that the target URL is a safe public endpoint (`http:`/`https:`) before passing to Microlink. Never forward loopbacks (`127.0.0.1`, `localhost`) or cloud metadata endpoints (`169.254.169.254`).
2. **Caching Strategy**: Cache successful Microlink responses in Redis / Key-Value stores for 7 days (`604800s`). Never cache failed requests.
3. **Timeout Gating**: Use `AbortSignal.timeout(4500)` to ensure fast edge worker execution without hanging client connections.

---

## 4. Verification & Testing

Validate Microlink integration:
1. Smoke-test endpoint response:
   ```bash
   curl -I "https://api.microlink.io?url=https://github.com"
   ```
2. Test SSRF protection by asserting private IP addresses are rejected before making network requests.

---

## 5. Common Pitfalls & Negative Constraints

- **Never pass internal network or localhost URLs to external APIs (SSRF risk).**
- **Avoid querying without timeout constraints:** Always attach an AbortSignal timeout.
- **Never cache failed or non-200 responses:** Only cache valid payloads with TTL.
