---
name: database-sql
description: Relational database design, migrations, and query tuning across PostgreSQL, Supabase, and SQL Server. Covers schema design, foreign keys, RLS security policies, EXPLAIN ANALYZE interpretation, index strategy, and N+1 query elimination. Use when designing database tables, writing SQL migrations, optimizing slow queries, or configuring Supabase/EF Core persistence.
---

# Database SQL Architecture, Schema Design & Query Optimization

Production guide for designing relational schemas and diagnosing database bottlenecks across PostgreSQL, Supabase, and SQL Server.

---

## 1. Schema Design & Security Standards

- **Strict Parameterization**: Never concatenate user input into raw SQL queries. Always use parameterized statements.
- **Normalization & Constraints**: Explicit primary keys (`UUID` or `BIGINT`), non-nullable foreign keys with `ON DELETE` constraints, and `CHECK` constraints for domain invariants.
- **Caching Layer Reference**: Consult [references/redis-cache-aside.md](references/redis-cache-aside.md) for complete patterns covering Redis Cache-Aside, namespaced keys, atomic Lua rate limiters, and graceful database fallback.
- **PostgreSQL / Supabase Row-Level Security (RLS)**:
  ```sql
  ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

  -- Read policy: tenant users can view their own projects
  CREATE POLICY "Users view own tenant projects" ON projects
    FOR SELECT USING (tenant_id = auth.jwt() ->> 'tenant_id');

  -- Write policy: authenticated owners only
  CREATE POLICY "Owners update projects" ON projects
    FOR UPDATE USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());
  ```
- **SQL Server / EF Core**: Keep schema source-of-truth in EF Core migrations or versioned `.sql` scripts. Enforce tenant isolation in repository query filters.

---

## 2. Query Plan Diagnosis (`EXPLAIN ANALYZE`)

Inspect query costs and execution bottlenecks before tuning:

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT u.id, u.email, COUNT(o.id) AS total_orders
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at >= '2026-01-01'
GROUP BY u.id, u.email
ORDER BY total_orders DESC
LIMIT 50;
```

### Execution Plan Warning Signals
- **Seq Scan**: Missing index on filtered column in large table.
- **Bitmap Heap Scan with High Filter Loss**: Filter condition not covered by composite index prefix.
- **Nested Loop with High Cost**: Unindexed foreign key in join condition.
- **Sort (Disk / external merge)**: Sort exceeded `work_mem`; add index matching `ORDER BY` direction.

---

## 3. Strategic Index Design

- **Composite Index Order**: Equality columns first, range / sort columns last:
  ```sql
  CREATE INDEX idx_orders_tenant_status_created 
  ON orders (tenant_id, status, created_at DESC);
  ```
- **Partial Indexes**: Index only high-traffic subsets to reduce index write amplification:
  ```sql
  CREATE INDEX idx_notifications_unread 
  ON notifications (user_id) 
  WHERE is_read = false;
  ```
- **Covering Indexes (`INCLUDE`)**: Satisfy queries entirely from index pages:
  ```sql
  CREATE INDEX idx_users_lookup 
  ON users (email) 
  INCLUDE (full_name, role);
  ```

---

## 4. N+1 Elimination & Batching

Never execute individual queries inside loops in application code. Batch using explicit `JOIN` or batched subqueries:
```sql
-- Good: Single batched query
SELECT o.id, o.order_number, json_agg(li.*) AS items
FROM orders o
LEFT JOIN line_items li ON li.order_id = o.id
WHERE o.user_id = :userId
GROUP BY o.id, o.order_number;
```

---

## 5. Verification & Testing

Validate query speed and index coverage:
```sql
-- Verify execution latency is under 50ms
EXPLAIN ANALYZE <your-query>;

-- Verify unused index cleanup
SELECT schemaname, relname, indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indisunique = false;
```

---

## 6. Common Pitfalls & Negative Constraints

- **Never perform un-parameterized raw SQL concatenation:** Prevents SQL injection vulnerabilities.
- **Never perform destructive table drops or column renames without expand-contract migrations.**
- **Avoid querying without pagination:** Never run unbounded `SELECT *` without explicit `LIMIT`.
- **Avoid un-indexed foreign keys:** Always index foreign key columns to prevent full table locks during cascading deletions.
