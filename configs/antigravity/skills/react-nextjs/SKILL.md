---
name: react-nextjs
description: Production architecture for React 19 and Next.js App Router applications. Covers Server Components, Server Actions, use() hook, useActionState, useOptimistic, Suspense boundaries, feature-sliced module layout, custom hooks with request cancellation, Vitest testing, and state management (RTK & Zustand). Use when building React/Next.js pages, components, custom hooks, services, or client stores.
---

# React 19 & Next.js App Router Architecture Guide

Comprehensive runbook for scalable, type-safe React 19 and Next.js App Router applications.

---

## 1. Architectural Principles

- **Default to Server Components**: Fetch data directly in Server Components on the server. Push `'use client'` to leaf components that require interactivity, state, or browser APIs.
- **Deep Reference Guide**: Consult [references/server-actions-patterns.md](references/server-actions-patterns.md) for complete implementations of Server Actions, `useActionState`, `useOptimistic`, streaming Suspense boundaries, and cancelable hooks.
- **Feature-Sliced Hierarchy**:
  ```
  src/
    ├── app/             # Next.js App Router (routes, layouts, loading, error)
    ├── components/      # Shared primitive UI (Button, Modal, Input)
    ├── features/        # Business domains (auth, billing, projects)
    │    └── auth/
    │         ├── components/
    │         ├── hooks/
    │         ├── services/
    │         └── types/
    ├── hooks/           # App-wide shared hooks
    └── lib/             # Shared utilities (cn, apiClient)
  ```
- **Zero Raw Side Effects**: Never trigger un-isolated async effects. Wrap in custom hooks with `AbortController` cancellation.

---

## 2. React 19 & App Router Core Patterns

### A. Server Components & Data Fetching
```tsx
// app/projects/page.tsx - Server Component
import { Suspense } from 'react';
import { ProjectList } from '@/features/projects/components/ProjectList';
import { ProjectListSkeleton } from '@/features/projects/components/Skeletons';

export default async function ProjectsPage() {
  const projectsPromise = fetch('https://api.example.com/projects', {
    next: { revalidate: 60 },
  }).then((r) => r.json());

  return (
    <main className="container mx-auto p-6">
      <h1 className="text-2xl font-bold tracking-tight mb-4">Projects</h1>
      <Suspense fallback={<ProjectListSkeleton />}>
        <ProjectList projectsPromise={projectsPromise} />
      </Suspense>
    </main>
  );
}
```

### B. use() Hook & Suspense Unwrapping
```tsx
'use client';
import { use } from 'react';
import type { Project } from '@/features/projects/types';

export function ProjectList({ projectsPromise }: { projectsPromise: Promise<Project[]> }) {
  const projects = use(projectsPromise);
  return (
    <ul className="divide-y divide-border">
      {projects.map((p) => (
        <li key={p.id} className="py-3 font-medium">{p.name}</li>
      ))}
    </ul>
  );
}
```

### C. Server Actions with useActionState & useOptimistic
```tsx
'use client';
import { useActionState, useOptimistic } from 'react';
import { updateProjectName } from '@/features/projects/actions';

export function ProjectRenameForm({ initialName, projectId }: { initialName: string; projectId: string }) {
  const [state, formAction, isPending] = useActionState(updateProjectName, { error: null });
  const [optimisticName, setOptimisticName] = useOptimistic(
    initialName,
    (current, update: string) => update
  );

  return (
    <form action={async (formData: FormData) => {
      const newName = formData.get('name') as string;
      setOptimisticName(newName);
      await formAction(formData);
    }}>
      <input type="hidden" name="id" value={projectId} />
      <input name="name" defaultValue={optimisticName} className="border px-3 py-1 rounded" />
      <button type="submit" disabled={isPending} className="btn-primary ml-2">
        {isPending ? 'Saving...' : 'Save'}
      </button>
      {state.error && <p className="text-destructive text-sm mt-1">{state.error}</p>}
    </form>
  );
}
```

---

## 3. Custom Hook with AbortController Pattern

```ts
import { useState, useEffect } from 'react';

export function useProject(projectId: string) {
  const [data, setData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const controller = new AbortController();

    async function load() {
      setIsLoading(true);
      try {
        const res = await fetch(`/api/projects/${projectId}`, { signal: controller.signal });
        const json = await res.json();
        setData(json);
      } catch (err: any) {
        if (err.name !== 'AbortError') console.error(err);
      } finally {
        setIsLoading(false);
      }
    }

    load();
    return () => controller.abort();
  }, [projectId]);

  return { data, isLoading };
}
```

---

## 4. State Management: Server vs Client vs RTK

- **Server Cache First**: Let Next.js Server Components, React Query, or RTK Query handle remote server data.
- **Local State**: Use `useState` / `useReducer` for component-local interactions.
- **Global Client State**: Use Redux Toolkit (RTK) or Zustand for cross-screen, multi-step flows:
  ```ts
  import { createSlice, type PayloadAction } from '@reduxjs/toolkit';

  export interface UserSession { id: string; email: string; role: 'admin' | 'user'; }
  interface AuthState { user: UserSession | null; isAuthenticated: boolean; }

  const initialState: AuthState = { user: null, isAuthenticated: false };
  export const authSlice = createSlice({
    name: 'auth',
    initialState,
    reducers: {
      setUser(state, action: PayloadAction<UserSession>) {
        state.user = action.payload;
        state.isAuthenticated = true;
      },
      clearUser(state) {
        state.user = null;
        state.isAuthenticated = false;
      },
    },
  });
  ```

---

## 5. Verification & Testing

Verify with Vitest & React Testing Library:
```bash
npm run test -- --watch=false
```
Always test state transitions, user interactions, and error boundaries without mocking the component under test.

---

## 6. Common Pitfalls & Negative Constraints

- Never perform data mutations directly inside Server Components; use Server Actions.
- Never use `'use client'` at the root of page or layout files.
- Avoid passing massive un-serialized class instances or functions across server-client boundaries.
- Never omit `AbortController` cancellation in async custom hooks.
