---
name: local-first-storage
description: Full-stack Local-First and client-side data architecture using Dexie.js (IndexedDB), reactive queries (useLiveQuery), schema versioning migrations, offline mutation queues, optimistic updates, and multi-tab synchronization.
---

# Local-First Storage & Offline-First Web Architecture

Production patterns for building resilient, zero-latency local-first web applications using **IndexedDB**, **Dexie.js**, reactive React hooks, background sync queues, and multi-tab coordination.

---

## When to Use This Skill

Trigger whenever designing or implementing:
- Client-side data storage using Dexie.js or native IndexedDB.
- Offline-capable PWAs that must function seamlessly without internet access.
- Schema migrations and upgrades across client devices.
- Reactive UI bindings via `useLiveQuery`.
- Mutation outbox queues, delta-sync, and conflict resolution (Last-Write-Wins, CRDT concepts).
- Storage quota estimation and persistent storage requests.
- Multi-tab synchronization using `BroadcastChannel`.

---

## 1. Local-First Core Principles

Adhere to the 7 ideals of local-first software (localfirstweb.dev):
1. **Zero Latency:** Reads and writes execute directly against local IndexedDB storage; UI never blocks on network roundtrips.
2. **Multi-device Availability:** Changes originate locally and synchronize asynchronously across all user nodes.
3. **Offline Sovereignty:** Full read and write capability persists during network partitions or offline states.
4. **Collaboration & Conflict Tolerance:** Concurrent modifications resolve cleanly without silent data loss.
5. **Longevity:** Data remains accessible even if central servers are discontinued.
6. **Privacy & Security First:** End-to-end encryption and client-side data boundaries.
7. **User Control:** Data export and import are always first-class citizens.

---

## 2. Dexie.js Typed Database & Schema Migrations

### Strongly Typed Database Definition
```typescript
// lib/db/schema.ts
import Dexie, { type Table } from 'dexie';

export interface NoteItem {
  id: string;
  title: string;
  content: string;
  tags: string[];
  createdAt: number;
  updatedAt: number;
  isDeleted: boolean;
  version: number;
}

export interface SyncMutation {
  id: string;
  entityType: 'note' | 'setting';
  entityId: string;
  operation: 'CREATE' | 'UPDATE' | 'DELETE';
  payload: Record<string, unknown>;
  timestamp: number;
  retryCount: number;
  status: 'pending' | 'syncing' | 'failed';
}

export class AppDatabase extends Dexie {
  notes!: Table<NoteItem, string>;
  syncQueue!: Table<SyncMutation, string>;

  constructor() {
    super('AppDatabase');

    // Version 1: Initial schema
    this.version(1).stores({
      notes: 'id, createdAt, updatedAt, *tags',
      syncQueue: 'id, status, timestamp, entityType'
    });

    // Version 2: Added isDeleted soft-delete flag and compound index
    this.version(2).stores({
      notes: 'id, createdAt, updatedAt, isDeleted, [isDeleted+updatedAt], *tags',
      syncQueue: 'id, status, timestamp, entityType'
    }).upgrade(async (tx) => {
      // Explicit data transformation during migration
      await tx.table('notes').toCollection().modify((note: Partial<NoteItem>) => {
        note.isDeleted = false;
        note.version = 1;
      });
    });
  }
}

export const db = new AppDatabase();
```

> **Index Key Syntax Reference:**
> - `id`: Primary key.
> - `++id`: Auto-incrementing primary key.
> - `*tags`: Multi-entry index (each array element is individually indexed for queries).
> - `[isDeleted+updatedAt]`: Compound index for efficient range queries and composite filtering.

---

## 3. Reactive React Queries with `useLiveQuery`

`useLiveQuery` automatically re-evaluates and triggers a component re-render whenever the queried IndexedDB table or index changes.

```tsx
// components/NoteList.tsx
import React from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../lib/db/schema';

interface NoteListProps {
  filterTag?: string;
}

export function NoteList({ filterTag }: NoteListProps) {
  const notes = useLiveQuery(
    async () => {
      if (filterTag) {
        return await db.notes
          .where('tags')
          .equals(filterTag)
          .filter(note => !note.isDeleted)
          .reverse()
          .sortBy('updatedAt');
      }

      return await db.notes
        .where('[isDeleted+updatedAt]')
        .between([false, Dexie.minKey], [false, Dexie.maxKey])
        .reverse()
        .toArray();
    },
    [filterTag] // Dependency array: re-run query if filterTag changes
  );

  if (notes === undefined) {
    return <div className="animate-pulse p-4 text-muted-foreground">Loading notes...</div>;
  }

  if (notes.length === 0) {
    return <div className="p-4 text-muted-foreground">No notes found.</div>;
  }

  return (
    <ul className="divide-y divide-border">
      {notes.map(note => (
        <li key={note.id} className="p-3 hover:bg-muted/50 transition-colors">
          <h3 className="font-semibold">{note.title}</h3>
          <p className="text-sm text-muted-foreground line-clamp-2">{note.content}</p>
        </li>
      ))}
    </ul>
  );
}
```

---

## 4. Offline Mutation Outbox & Delta-Sync Engine

All write operations write directly to local storage AND enqueue an entry into `syncQueue` in a single Dexie transaction.

### Local Write & Enqueue Transaction
```typescript
// services/noteService.ts
import { db, type NoteItem, type SyncMutation } from '../lib/db/schema';

export async function createNote(title: string, content: string, tags: string[]): Promise<string> {
  const noteId = crypto.randomUUID();
  const timestamp = Date.now();

  const newNote: NoteItem = {
    id: noteId,
    title,
    content,
    tags,
    createdAt: timestamp,
    updatedAt: timestamp,
    isDeleted: false,
    version: 1,
  };

  const mutation: SyncMutation = {
    id: crypto.randomUUID(),
    entityType: 'note',
    entityId: noteId,
    operation: 'CREATE',
    payload: newNote,
    timestamp,
    retryCount: 0,
    status: 'pending',
  };

  // Atomically persist note and queue synchronization
  await db.transaction('rw', [db.notes, db.syncQueue], async () => {
    await db.notes.add(newNote);
    await db.syncQueue.add(mutation);
  });

  // Notify other tabs and trigger background pump
  broadcastSyncSignal();
  triggerSyncWorker();

  return noteId;
}
```

### Sync Engine with Exponential Backoff
```typescript
// services/syncEngine.ts
import { db, type SyncMutation } from '../lib/db/schema';

let isSyncing = false;

export async function triggerSyncWorker(): Promise<void> {
  if (isSyncing || !navigator.onLine) return;
  isSyncing = true;

  try {
    const pendingMutations = await db.syncQueue
      .where('status')
      .equals('pending')
      .sortBy('timestamp');

    for (const mutation of pendingMutations) {
      try {
        await db.syncQueue.update(mutation.id, { status: 'syncing' });

        const response = await fetch('/api/sync', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(mutation),
        });

        if (response.ok) {
          // Mutation succeeded on server; remove from outbox
          await db.syncQueue.delete(mutation.id);
        } else if (response.status >= 400 && response.status < 500) {
          // Client/validation error; mark failed
          await db.syncQueue.update(mutation.id, { status: 'failed' });
        } else {
          // Transient server error; increment retry count
          throw new Error(`Transient sync error: ${response.statusText}`);
        }
      } catch (err) {
        const nextRetry = mutation.retryCount + 1;
        await db.syncQueue.update(mutation.id, {
          status: 'pending',
          retryCount: nextRetry,
        });
        break; // Stop queue processing on network failure
      }
    }
  } finally {
    isSyncing = false;
  }
}

// Automatically sync when back online
window.addEventListener('online', () => {
  triggerSyncWorker();
});
```

---

## 5. Multi-Tab Synchronization via `BroadcastChannel`

```typescript
// lib/sync/tabChannel.ts
const SYNC_CHANNEL_NAME = 'app-storage-sync';
const channel = typeof BroadcastChannel !== 'undefined'
  ? new BroadcastChannel(SYNC_CHANNEL_NAME)
  : null;

export function broadcastSyncSignal(): void {
  channel?.postMessage({ type: 'DATA_CHANGED', timestamp: Date.now() });
}

export function subscribeToTabEvents(onSync: () => void): () => void {
  if (!channel) return () => {};

  const handler = (event: MessageEvent) => {
    if (event.data?.type === 'DATA_CHANGED') {
      onSync();
    }
  };

  channel.addEventListener('message', handler);
  return () => channel.removeEventListener('message', handler);
}
```

---

## 6. Storage Quota & Persistent Storage Management

Browsers may evict IndexedDB data under storage pressure unless persistent storage is granted.

```typescript
// lib/storage/quota.ts
export interface StorageStatus {
  usageBytes: number;
  quotaBytes: number;
  percentageUsed: number;
  isPersisted: boolean;
}

export async function checkStorageStatus(): Promise<StorageStatus> {
  let isPersisted = false;
  let usageBytes = 0;
  let quotaBytes = 0;

  if (navigator.storage && navigator.storage.persisted) {
    isPersisted = await navigator.storage.persisted();
  }

  if (navigator.storage && navigator.storage.estimate) {
    const estimate = await navigator.storage.estimate();
    usageBytes = estimate.usage ?? 0;
    quotaBytes = estimate.quota ?? 0;
  }

  const percentageUsed = quotaBytes > 0 ? (usageBytes / quotaBytes) * 100 : 0;

  return {
    usageBytes,
    quotaBytes,
    percentageUsed: Number(percentageUsed.toFixed(1)),
    isPersisted,
  };
}

export async function requestPersistentStorage(): Promise<boolean> {
  if (navigator.storage && navigator.storage.persist) {
    return await navigator.storage.persist();
  }
  return false;
}
```

---

## 7. Web Share Target Integration (PWA Ingest)

When configured in `manifest.json`, incoming files or shared URLs can be ingested directly into IndexedDB without backend intervention.

```typescript
// Service Worker share handler (sw.ts)
self.addEventListener('fetch', (event: any) => {
  const url = new URL(event.request.url);

  if (url.pathname === '/share-target' && event.request.method === 'POST') {
    event.respondWith(
      (async () => {
        const formData = await event.request.formData();
        const title = formData.get('title') || '';
        const text = formData.get('text') || '';
        const urlParam = formData.get('url') || '';

        // Store shared payload in temporary cache or directly notify client
        const clientList = await (self as any).clients.matchAll({ type: 'window' });
        for (const client of clientList) {
          client.postMessage({
            type: 'SHARE_INGEST',
            payload: { title, text, url: urlParam },
          });
        }

        return Response.redirect('/', 303);
      })()
    );
  }
});
```
