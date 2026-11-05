# React 19 & Next.js Server Actions: Advanced Patterns

Comprehensive technical guide for React 19 and Next.js App Router server actions, optimistic UI state, suspense boundaries, and resilient data-fetching hooks.

---

## 1. Type-Safe Server Action Contract

Server actions execute on the server and must validate all incoming formData or arguments at the runtime boundary using Zod before invoking domain logic.

```typescript
// app/actions/project-actions.ts
'use server';

import { z } from 'zod';
import { revalidatePath } from 'next/cache';
import { projectService } from '@/services/project-service';

const UpdateProjectSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(2).max(100),
});

export type ActionState = {
  success: boolean;
  message?: string;
  fieldErrors?: Record<string, string[]>;
  data?: { id: string; name: string };
};

export async function updateProjectAction(
  prevState: ActionState,
  formData: FormData
): Promise<ActionState> {
  const rawData = {
    id: formData.get('id'),
    name: formData.get('name'),
  };

  const parsed = UpdateProjectSchema.safeParse(rawData);
  if (!parsed.success) {
    return {
      success: false,
      fieldErrors: parsed.error.flatten().fieldErrors,
    };
  }

  const result = await projectService.updateProject(parsed.data.id, parsed.data.name);
  if (!result.isOk) {
    return {
      success: false,
      message: result.error.message,
    };
  }

  revalidatePath('/projects');
  return {
    success: true,
    data: result.value,
  };
}
```

---

## 2. useActionState with Optimistic UI (useOptimistic)

React 19 replaces `useFormState` with `useActionState`. Combine with `useOptimistic` for instant UI feedback with automatic rollback on error.

```tsx
// components/ProjectRenameForm.tsx
'use client';

import { useActionState, useOptimistic, startTransition } from 'react';
import { updateProjectAction, type ActionState } from '@/app/actions/project-actions';

interface Props {
  project: { id: string; name: string };
}

const initialState: ActionState = { success: false };

export function ProjectRenameForm({ project }: Props) {
  const [state, formAction, isPending] = useActionState(updateProjectAction, initialState);

  const [optimisticName, setOptimisticName] = useOptimistic(
    project.name,
    (_current: string, nextName: string) => nextName
  );

  const handleSubmit = (formData: FormData) => {
    const nextName = formData.get('name') as string;
    startTransition(async () => {
      setOptimisticName(nextName);
      await formAction(formData);
    });
  };

  return (
    <form action={handleSubmit} className="flex flex-col gap-2 max-w-md">
      <input type="hidden" name="id" value={project.id} />
      
      <label htmlFor="name" className="text-sm font-medium text-slate-700">
        Project Name
      </label>
      <input
        id="name"
        name="name"
        defaultValue={optimisticName}
        disabled={isPending}
        className="rounded border border-slate-300 px-3 py-2 text-sm focus:border-slate-900 focus:outline-none"
      />

      {state.fieldErrors?.name && (
        <span className="text-xs text-red-600">{state.fieldErrors.name[0]}</span>
      )}

      {state.message && (
        <span className="text-xs text-red-600">{state.message}</span>
      )}

      <button
        type="submit"
        disabled={isPending}
        className="rounded bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800 disabled:opacity-50"
      >
        {isPending ? 'Saving changes...' : 'Save Changes'}
      </button>
    </form>
  );
}
```

---

## 3. Streaming Suspense Boundaries & Promise Unwrapping

React 19 allows passing un-awaited promises from Server Components directly into Client Components using `use()`.

```tsx
// app/dashboard/page.tsx (Server Component)
import { Suspense } from 'react';
import { MetricsView } from './MetricsView';
import { MetricsSkeleton } from './MetricsSkeleton';
import { fetchMetricsPromise } from '@/lib/metrics';

export default function DashboardPage() {
  // Start data fetching on server without awaiting
  const metricsPromise = fetchMetricsPromise();

  return (
    <section className="space-y-6">
      <h1 className="text-xl font-semibold">Analytics Dashboard</h1>
      <Suspense fallback={<MetricsSkeleton />}>
        <MetricsView metricsPromise={metricsPromise} />
      </Suspense>
    </section>
  );
}
```

```tsx
// app/dashboard/MetricsView.tsx (Client Component)
'use client';

import { use } from 'react';
import type { DashboardMetrics } from '@/types/metrics';

export function MetricsView({ metricsPromise }: { metricsPromise: Promise<DashboardMetrics> }) {
  // Unwraps promise within Suspense boundary
  const metrics = use(metricsPromise);

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div className="p-4 rounded border bg-white">
        <p className="text-sm text-slate-500">Total Users</p>
        <p className="text-2xl font-bold">{metrics.totalUsers.toLocaleString()}</p>
      </div>
      <div className="p-4 rounded border bg-white">
        <p className="text-sm text-slate-500">Active Sessions</p>
        <p className="text-2xl font-bold">{metrics.activeSessions.toLocaleString()}</p>
      </div>
      <div className="p-4 rounded border bg-white">
        <p className="text-sm text-slate-500">Conversion Rate</p>
        <p className="text-2xl font-bold">{(metrics.conversionRate * 100).toFixed(1)}%</p>
      </div>
    </div>
  );
}
```

---

## 4. Cancelable Custom Hooks with AbortController

Prevent state updates after unmount or on rapid input changes by coupling `useEffect` with `AbortController`.

```typescript
// hooks/use-debounced-search.ts
import { useState, useEffect } from 'react';

export function useDebouncedSearch<T>(query: string, delayMs = 300) {
  const [results, setResults] = useState<T[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!query.trim()) {
      setResults([]);
      setIsSearching(false);
      return;
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(async () => {
      setIsSearching(true);
      setError(null);

      try {
        const response = await fetch(`/api/search?q=${encodeURIComponent(query)}`, {
          signal: controller.signal,
        });

        if (!response.ok) {
          throw new Error(`Search failed: ${response.statusText}`);
        }

        const data: T[] = await response.json();
        setResults(data);
      } catch (err: unknown) {
        if (err instanceof DOMException && err.name === 'AbortError') {
          // Request intentionally canceled; ignore
          return;
        }
        setError(err instanceof Error ? err.message : 'Unknown search error');
      } finally {
        setIsSearching(false);
      }
    }, delayMs);

    return () => {
      clearTimeout(timeoutId);
      controller.abort();
    };
  }, [query, delayMs]);

  return { results, isSearching, error };
}
```

---

## 5. Negative Constraints & Common Pitfalls

- **Never perform mutations in Server Components:** Always delegate writes to Server Actions or Route Handlers.
- **Never trust client arguments without schema validation:** Every Server Action must validate inputs with Zod.
- **Avoid raw fetch in client components:** Use Server Components or dedicated React Query/SWR hooks for data fetching.
- **Never leak sensitive environment variables to the client:** Only use `NEXT_PUBLIC_` for variables meant for client bundles.
