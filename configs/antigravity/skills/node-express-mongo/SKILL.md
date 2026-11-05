---
name: node-express-mongo
description: Architecture standards and implementation patterns for Node.js, Express, and MongoDB/Mongoose backends with TypeScript. Use when building REST APIs, controllers, domain services, Mongoose models/schemas, generic repositories, Zod validation, or unit testing MERN backends.
---

# Node.js, Express & Mongoose Clean Architecture Guide

Runbook for building layered, typed Express backends with Mongoose and MongoDB.

## 1. Architectural Layers & Responsibilities

```
[HTTP Request] --> [Zod Validation Middleware]
                           |
                  [Express Controller] --> Extracts params/body, returns HTTP envelope
                           |
                  [Domain Service]     --> Business rules, returns Result<T, Error>
                           |
                  [Repository Layer]   --> Mongoose queries (find, create, update, delete)
                           |
                  [MongoDB Database]
```

- **Controllers never touch Mongoose models directly.**
- **Services never handle raw Express `req` or `res` objects.**
- **Mongoose models and schemas live strictly inside the Repository/Data layer.**
- **Deep Reference Guides**:
  - Consult [references/express-mongo-patterns.md](references/express-mongo-patterns.md) for Zod edge validation middleware, Express 5 native async error handling, Mongoose compound indexes, and generic Mongoose repositories.
  - Consult [references/code-patterns.md](references/code-patterns.md) for base repository and controller implementations.

---

## 2. Core Implementation Patterns

### Schema & Result Contract
```ts
export type Result<T, E = string> = 
  | { success: true; data: T }
  | { success: false; error: E; code?: number };

export const UserSchema = new Schema<IUserDocument>(
  {
    email: { type: String, required: true, unique: true, lowercase: true, index: true },
    fullName: { type: String, required: true },
    role: { type: String, enum: ['admin', 'user'], default: 'user' },
  },
  { timestamps: true }
);
```

---

## 3. Global Error Handling Middleware

```ts
import { Request, Response, NextFunction } from 'express';

export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  console.error('[Unhandled Server Error]:', err.stack || err.message);
  res.status(500).json({
    success: false,
    message: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message,
  });
}
```

---

## 4. Verification & Testing

Verify service domain logic and API routes:
1. **Unit Tests (AAA Pattern):**
   ```bash
   npm test -- user.service.test.ts
   ```
2. **Integration API Route Test:**
   ```bash
   npm test -- user.api.test.ts
   ```
3. **Mongoose Schema Validation Check:** Verify unique indexes are created properly in MongoDB test instances.

---

## 5. Common Pitfalls & Negative Constraints

- **Never query Mongoose models in controllers:** Always route database access through repository classes.
- **Never bypass Zod validation:** Validate all `req.body`, `req.params`, and `req.query` at the route edge.
- **Never swallow unhandled rejections:** Always forward errors to `next(error)`.
