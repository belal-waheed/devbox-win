---
name: pwa-service-worker
description: Progressive Web App (PWA) patterns including service worker setup, caching strategies, offline support, manifest.json, and iOS/Android install support. Use when implementing offline support, web app manifests, or service worker caching.
---

# PWA Service Worker Skill

Runbook for implementing Progressive Web App (PWA) capabilities, offline caching strategies, and install manifests.

## 1. Core Workflow

1. **Manifest Configuration:** Define `public/manifest.json` with icons, theme color, and standalone display.
2. **HTML Meta Tags:** Inject viewport, `theme-color`, and Apple touch icons in `index.html`.
3. **Caching Strategies in Service Worker:**
   - **Static Assets:** Cache-First strategy with versioned cache keys.
   - **API Routes (`/api/*`):** Network-First strategy with offline JSON fallback.
   - **Navigation Mode:** Fallback to cached `index.html`.
4. **Registration:** Register service worker only in production builds.

---

## 2. Production Service Worker Pattern

```javascript
const STATIC_CACHE = 'app-static-v1';
const API_CACHE = 'app-api-v1';

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => cache.addAll(['/', '/index.html', '/manifest.json'])).then(() => self.skipWaiting())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  if (request.method !== 'GET') return;

  if (url.pathname.startsWith('/api/')) {
    event.respondWith(networkFirst(request, API_CACHE));
    return;
  }
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(() => caches.match('/index.html')));
    return;
  }
  event.respondWith(cacheFirst(request, STATIC_CACHE));
});
```

---

## 3. Verification & Testing

Validate PWA and offline behavior:
1. **Lighthouse PWA Audit:**
   ```bash
   npx lighthouse http://localhost:4173 --only-categories=pwa
   ```
2. **Offline Simulation Test:** In Edge DevTools -> Network -> set to "Offline" and refresh page; verify app loads without network errors.
3. **Manifest Validation:** Verify `manifest.json` parses as valid JSON with valid icon image paths.

---

## 4. Common Pitfalls & Negative Constraints

- **Never enable service workers in dev mode:** Service worker caching interferes with Vite/Webpack HMR.
- **Never cache API responses with Cache-First:** Always use Network-First for dynamic endpoints.
- **Never omit navigation fallback:** Navigation requests must fall back to `index.html` to avoid offline blank screens.
