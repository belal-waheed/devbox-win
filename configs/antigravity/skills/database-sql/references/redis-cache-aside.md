# Redis Cache-Aside Pattern, Namespaces & Resilience

Production guide for implementing Redis as a high-performance cache layer alongside relational or document databases.

---

## 1. Cache-Aside Pattern Architecture

Under the Cache-Aside pattern, the application code mediates between the cache and the primary database.

```
Read Flow:
Application ──1. GET key──► Redis Cache
    │                           │
    ├───────2. Hit (Return)◄────┘
    ▼
 (Miss)
    │
    ├───────3. Query DB───► PostgreSQL / SQL Server
    │                           │
    ├───────4. Return Data◄─────┘
    ▼
Application ──5. SET key (with TTL)──► Redis Cache
```

```typescript
// services/user-cache-service.ts
import { redisClient } from '@/lib/redis';
import { db } from '@/lib/db';

export async function getUserById(userId: string) {
  const cacheKey = `user:${userId}:v1`;

  // 1. Try reading from Redis with resilience fallback
  try {
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }
  } catch (cacheErr) {
    // Non-fatal cache failure: log and degrade gracefully to DB
    console.error('Redis read failure, falling back to database', cacheErr);
  }

  // 2. Query database on cache miss or cache failure
  const user = await db.user.findUnique({ where: { id: userId } });
  if (!user) return null;

  // 3. Write back to Redis asynchronously with explicit TTL (1 hour)
  try {
    await redisClient.set(cacheKey, JSON.stringify(user), 'EX', 3600);
  } catch (cacheErr) {
    console.error('Redis write failure', cacheErr);
  }

  return user;
}
```

---

## 2. Standardized Key Namespaces

Never use unstructured or collision-prone key strings. Enforce a hierarchical namespace convention:

```
[app]:[domain]:[entity-id]:[field/relation]:[schema-version]
```

Examples:
- `app:orders:usr_99812:recent:v1`
- `app:sessions:tok_abc123:meta:v1`
- `app:ratelimit:ip_192.168.1.1:minute:v1`

**Rules:**
- Every key MUST have an explicit Time-To-Live (TTL).
- Version keys (`:v1`) so schema mutations do not corrupt live processes during rolling deployments.
- Invalidate specific keys immediately upon write/update operations (`redisClient.del(cacheKey)`).

---

## 3. Atomic Rate Limiter with Lua Script

Application-level read-then-write rate limiters suffer from concurrency race conditions. Always use atomic Lua scripts executed on Redis:

```lua
-- scripts/rate_limiter.lua
-- KEYS[1]: Rate limit key (e.g. ratelimit:ip:timestamp)
-- ARGV[1]: Max requests allowed
-- ARGV[2]: Window window in seconds

local current = redis.call('INCR', KEYS[1])
if tonumber(current) == 1 then
    redis.call('EXPIRE', KEYS[1], ARGV[2])
end

if tonumber(current) > tonumber(ARGV[1]) then
    return 0 -- Rate limit exceeded
else
    return 1 -- Allowed
end
```

```typescript
// middleware/rate-limit.ts
import { redisClient } from '@/lib/redis';

const RATE_LIMIT_LUA = `
local current = redis.call('INCR', KEYS[1])
if tonumber(current) == 1 then
    redis.call('EXPIRE', KEYS[1], ARGV[2])
end
if tonumber(current) > tonumber(ARGV[1]) then
    return 0
else
    return 1
end
`;

export async function checkRateLimit(identifier: string, maxRequests = 60, windowSeconds = 60): Promise<boolean> {
  const key = `ratelimit:${identifier}:v1`;
  try {
    const result = await redisClient.eval(RATE_LIMIT_LUA, 1, key, maxRequests, windowSeconds);
    return result === 1;
  } catch (err) {
    // If rate limiter fails, fail open or closed based on security policy
    console.error('Rate limit evaluation error', err);
    return true; // Fail open to maintain availability
  }
}
```

---

## 4. Connection Resilience & Exponential Backoff

```typescript
// lib/redis.ts
import Redis from 'ioredis';

export const redisClient = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: 3,
  retryStrategy(times) {
    const delay = Math.min(times * 100, 3000);
    return delay;
  },
  reconnectOnError(err) {
    const targetError = 'READONLY';
    if (err.message.includes(targetError)) {
      return true; // Reconnect on replica switch
    }
    return false;
  },
  enableOfflineQueue: true,
  connectTimeout: 5000,
});

redisClient.on('error', (err) => {
  console.error('Redis client error:', err.message);
});
```

---

## 5. Negative Constraints & Common Anti-Patterns

- **Never omit TTL on cached entities:** Unbounded keys cause out-of-memory crashes.
- **Never treat Redis as the sole system of record:** Always ensure persistence in relational/document DB unless explicitly designed for ephemeral queues.
- **Avoid multi-key transactions across shards:** In cluster mode, multi-key operations require hash tags (e.g. `{user:123}:profile`).
- **Never fail user requests on cache downtime:** Degrade gracefully to primary database queries.
