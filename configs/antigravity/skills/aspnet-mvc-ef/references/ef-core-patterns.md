# EF Core Architecture, Generic Repository & High-Performance Query Patterns

Production conventions and implementation standards for ASP.NET Core with Entity Framework Core (EF Core).

---

## 1. DbContext Pooling & Registration

Avoid DbContext instantiation overhead on high-throughput services by enabling DbContext Pooling in `Program.cs`:

```csharp
builder.Services.AddDbContextPool<AppDbContext>(options =>
{
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"), npgsqlOptions =>
    {
        npgsqlOptions.EnableRetryOnFailure(
            maxRetryCount: 3,
            maxRetryDelay: TimeSpan.FromSeconds(5),
            errorCodesToAdd: null);
        npgsqlOptions.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery);
    });

    if (builder.Environment.IsDevelopment())
    {
        options.EnableSensitiveDataLogging();
        options.EnableDetailedErrors();
    }
}, poolSize: 128);
```

---

## 2. Generic Repository & Unit of Work Pattern

```csharp
// Repositories/IRepository.cs
public interface IRepository<TEntity> where TEntity : class
{
    Task<TEntity?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<TEntity>> ListAsync(ISpecification<TEntity>? spec = null, CancellationToken ct = default);
    Task AddAsync(TEntity entity, CancellationToken ct = default);
    void Update(TEntity entity);
    void Delete(TEntity entity);
}

// Repositories/EfRepository.cs
public class EfRepository<TEntity> : IRepository<TEntity> where TEntity : class
{
    protected readonly AppDbContext _context;
    protected readonly DbSet<TEntity> _dbSet;

    public EfRepository(AppDbContext context)
    {
        _context = context;
        _dbSet = context.Set<TEntity>();
    }

    public async Task<TEntity?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        return await _dbSet.FindAsync(new object[] { id }, ct);
    }

    public async Task<IReadOnlyList<TEntity>> ListAsync(ISpecification<TEntity>? spec = null, CancellationToken ct = default)
    {
        IQueryable<TEntity> query = _dbSet.AsNoTracking();
        if (spec != null)
        {
            query = spec.Apply(query);
        }
        return await query.ToListAsync(ct);
    }

    public async Task AddAsync(TEntity entity, CancellationToken ct = default)
    {
        await _dbSet.AddAsync(entity, ct);
    }

    public void Update(TEntity entity)
    {
        _dbSet.Update(entity);
    }

    public void Delete(TEntity entity)
    {
        _dbSet.Remove(entity);
    }
}
```

---

## 3. Result<T, E> Envelope Type for Business Logic

Controllers should not throw exceptions for predicted business domain errors. Services encapsulate logic and return explicit `Result<TValue, TError>`:

```csharp
// Common/Result.cs
public readonly struct Result<TValue, TError>
{
    public readonly TValue? Value;
    public readonly TError? Error;
    public bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;

    private Result(TValue value)
    {
        IsSuccess = true;
        Value = value;
        Error = default;
    }

    private Result(TError error)
    {
        IsSuccess = false;
        Value = default;
        Error = error;
    }

    public static Result<TValue, TError> Ok(TValue value) => new(value);
    public static Result<TValue, TError> Fail(TError error) => new(error);

    public TResult Match<TResult>(Func<TValue, TResult> onSuccess, Func<TError, TResult> onFailure) =>
        IsSuccess ? onSuccess(Value!) : onFailure(Error!);
}

// Usage in Domain Service
public async Task<Result<OrderDto, DomainError>> ProcessOrderAsync(CreateOrderCommand cmd, CancellationToken ct)
{
    var customer = await _customerRepo.GetByIdAsync(cmd.CustomerId, ct);
    if (customer == null)
        return Result<OrderDto, DomainError>.Fail(new NotFoundError($"Customer {cmd.CustomerId} not found"));

    if (!customer.HasSufficientCredit(cmd.TotalAmount))
        return Result<OrderDto, DomainError>.Fail(new ValidationError("Insufficient customer credit"));

    var order = Order.Create(cmd);
    await _orderRepo.AddAsync(order, ct);
    await _unitOfWork.SaveChangesAsync(ct);

    return Result<OrderDto, DomainError>.Ok(order.ToDto());
}
```

---

## 4. Query Performance: AsNoTracking & AsSplitQuery

Avoid tracking overhead on read-only queries and avoid cartesian explosion on 1-to-many joins:

```csharp
// High performance read query
public async Task<List<OrderSummaryDto>> GetRecentOrdersAsync(Guid customerId, CancellationToken ct)
{
    return await _context.Orders
        .AsNoTracking() // Eliminates identity map tracking overhead
        .AsSplitQuery() // Executes separate SELECTs instead of massive Cartesian JOIN
        .Where(o => o.CustomerId == customerId)
        .OrderByDescending(o => o.CreatedAtUtc)
        .Take(20)
        .Select(o => new OrderSummaryDto(o.Id, o.Total, o.Items.Count, o.Status))
        .ToListAsync(ct);
}
```

---

## 5. Migration Safety Checklist

1. **Zero Breaking Schema Drops in Step 1:** Use expand-contract. Never drop or rename columns in active tables without phased deployments.
2. **Nullable New Columns:** New columns added to existing tables must either be nullable or have an explicit default value.
3. **Concurrent Indexes:** Create indexes concurrently on high-volume production tables:
   ```csharp
   migrationBuilder.CreateIndex(
       name: "IX_Orders_CustomerId",
       table: "Orders",
       column: "CustomerId",
       unique: false);
   ```
4. **Idempotent Migration Scripts:** Always generate SQL scripts for production deployments:
   ```powershell
   dotnet ef migrations script --idempotent --output ./migrations.sql
   ```
