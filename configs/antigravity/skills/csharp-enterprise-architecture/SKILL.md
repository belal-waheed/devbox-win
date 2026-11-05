---
name: csharp-enterprise-architecture
description: Dual-mode C# architecture guide for Socratic OOP study and enterprise production patterns (Clean Architecture, Vertical Slice, CQRS with MediatR, Result<T, E>, FluentValidation, EF Core). Use when learning or designing C# OOP systems, academic coursework, or production backend services.
---

# C# Enterprise Architecture & Academic Mentorship Guide

Comprehensive guide for modern C# development across two distinct modes: **Socratic Academic Mentorship** for university-level OOP coursework and **Enterprise Production Hardening** for scalable, high-throughput .NET systems.

---

## Mode Detection & Routing

| User Intent | Activated Mode | Behavioral Stance |
|---|---|---|
| Homework, lab assignments, university exam prep, understanding OOP concepts, "why does this fail?" | **Mode A: Socratic Study** | Never output direct solutions. Guide via inquiry, memory diagrams, edge case exploration, and conceptual hints. |
| Production codebases, enterprise services, refactoring legacy APIs, CQRS, MediatR, DDD patterns | **Mode B: Production Hardening** | Provide production-grade C# 12/13 implementations, zero-allocation patterns, Clean/Vertical Slice architecture, and robust test suites. |

---

## Mode A: Socratic Study & Assignment Mentor

When a user presents an academic problem, homework exercise, or conceptual inquiry, adhere strictly to the following rules:

### 1. Pedagogical Rules of Engagement
- **Never dump the full answer:** Refuse to write complete homework solutions. Instead, provide pseudo-code skeletons, class blueprints, or targeted 2-3 line snippets.
- **Ask guiding questions:** Prompt the student to identify invariants, preconditions, and design trade-offs.
- **Deconstruct mental models:** Use ASCII memory layouts (Stack vs Heap) to demystify pointers, references, and allocation costs.
- **Analyze edge cases:** Ask the student what happens when `null`, empty collections, or boundary values are passed into their methods.

### 2. Foundational Memory & Type System Concepts

#### Value Types vs. Reference Types
- **Value Types (`struct`, primitive types, `enum`):** Stored inline wherever declared (on the thread stack for local variables, or embedded within the object heap if a field of a class). Passed by value (copying bits) unless passed with `in`, `ref`, or `out`.
- **Reference Types (`class`, `record class`, `interface`, `delegate`, `string`, arrays):** Allocated on the Managed Heap. The variable itself holds only a memory pointer (8 bytes on 64-bit systems) located on the stack or enclosing object.

#### Boxing and Unboxing Overhead
```csharp
// Boxing: Copies value-type from stack to a new heap allocation wrapped in an object header
int number = 42;
object boxed = number; // Allocates ~24-32 bytes on heap (header + payload)

// Unboxing: Extracts bit-copy from heap object back to stack (requires type check)
int unboxed = (int)boxed; // Throws InvalidCastException if types do not match exactly
```

> **Socratic Prompt:** *"When you pass an `int` to a non-generic collection like `ArrayList` or `string.Format("{0}", id)`, what happens to the memory allocator? How does `List<T>` eliminate this penalty?"*

#### The Anatomy of the CLR Object Header
Every heap object in the .NET runtime carries an overhead:
1. **SyncBlock Index (4 bytes on 32-bit, 8 bytes on 64-bit):** Used for thread locking (`lock(obj)`), hash code caching, and COM interop.
2. **MethodTable Pointer / Type Handle (4/8 bytes):** Points to the EEClass metadata defining the runtime type, virtual method table (vtable), and interface mapping tables.
3. **Payload / Fields:** The actual instance fields aligned to processor word boundaries.

---

## Mode B: Production Hardening (Enterprise C# 12/13)

When building production APIs and enterprise backends, implement the following architectural standards.

### 1. Clean Architecture & Vertical Slice Structure

```
Application Layer (Features / Vertical Slices)
  ├── Features/
  │   └── Orders/
  │       ├── CreateOrder/
  │       │   ├── CreateOrderCommand.cs
  │       │   ├── CreateOrderHandler.cs
  │       │   ├── CreateOrderValidator.cs
  │       │   └── CreateOrderEndpoint.cs
  │       └── GetOrderById/
Domain Layer (Pure, Zero External Dependencies)
  ├── Entities/
  ├── ValueObjects/
  ├── DomainEvents/
  └── Errors/
Infrastructure Layer (External Adapters)
  ├── Persistence/ (EF Core DbContext, Configurations)
  ├── Messaging/   (RabbitMQ, Azure Service Bus)
  └── Services/    (Payment gateways, Email providers)
```

### 2. Functional Error Handling with `Result<T, E>`

Never use exceptions for anticipated domain logic or validation failures. Use a typed `Result` pattern.

```csharp
// Domain/Primitives/Result.cs
public readonly record struct Error(string Code, string Description)
{
    public static readonly Error None = new(string.Empty, string.Empty);
    public static readonly Error NullValue = new("Error.NullValue", "The specified value is null.");
}

public class Result
{
    protected internal Result(bool isSuccess, Error error)
    {
        if (isSuccess && error != Error.None || !isSuccess && error == Error.None)
            throw new InvalidOperationException("Invalid error state for Result.");

        IsSuccess = isSuccess;
        Error = error;
    }

    public bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;
    public Error Error { get; }

    public static Result Success() => new(true, Error.None);
    public static Result Failure(Error error) => new(false, error);
}

public class Result<TValue> : Result
{
    private readonly TValue? _value;

    protected internal Result(TValue? value, bool isSuccess, Error error)
        : base(isSuccess, error) => _value = value;

    public TValue Value => IsSuccess
        ? _value!
        : throw new InvalidOperationException("The value of a failure result cannot be accessed.");

    public static Result<TValue> Success(TValue value) => new(value, true, Error.None);
    public static new Result<TValue> Failure(Error error) => new(default, false, error);
}
```

### 3. CQRS & MediatR Pipeline Execution

#### Command & Handler Definition
```csharp
// Features/Orders/CreateOrder/CreateOrderCommand.cs
using MediatR;

public sealed record CreateOrderCommand(
    Guid CustomerId,
    IReadOnlyList<OrderItemDto> Items) : IRequest<Result<Guid>>;

public sealed class CreateOrderCommandHandler(
    IOrderRepository orderRepository,
    IUnitOfWork unitOfWork) : IRequestHandler<CreateOrderCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(
        CreateOrderCommand request,
        CancellationToken cancellationToken)
    {
        var orderResult = Order.Create(request.CustomerId);
        if (orderResult.IsFailure)
        {
            return Result<Guid>.Failure(orderResult.Error);
        }

        var order = orderResult.Value;
        foreach (var item in request.Items)
        {
            var addItemResult = order.AddItem(item.ProductId, item.Quantity, item.UnitPrice);
            if (addItemResult.IsFailure)
            {
                return Result<Guid>.Failure(addItemResult.Error);
            }
        }

        await orderRepository.AddAsync(order, cancellationToken);
        await unitOfWork.SaveChangesAsync(cancellationToken);

        return Result<Guid>.Success(order.Id);
    }
}
```

#### Pipeline Behaviors: Validation & Logging
```csharp
// Common/Behaviors/ValidationPipelineBehavior.cs
using FluentValidation;
using MediatR;

public sealed class ValidationPipelineBehavior<TRequest, TResponse>(
    IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IRequest<TResponse>
    where TResponse : Result
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (!validators.Any())
        {
            return await next();
        }

        var context = new ValidationContext<TRequest>(request);

        var validationFailures = await Task.WhenAll(
            validators.Select(validator => validator.ValidateAsync(context, cancellationToken)));

        var errors = validationFailures
            .SelectMany(result => result.Errors)
            .Where(f => f != null)
            .Select(failure => new Error(failure.PropertyName, failure.ErrorMessage))
            .Distinct()
            .ToArray();

        if (errors.Length != 0)
        {
            return CreateValidationResult<TResponse>(errors[0]);
        }

        return await next();
    }

    private static TResponse CreateValidationResult<TResult>(Error error)
        where TResult : Result
    {
        if (typeof(TResult) == typeof(Result))
        {
            return (Result.Failure(error) as TResponse)!;
        }

        var resultType = typeof(TResult).GetGenericArguments()[0];
        var failureMethod = typeof(Result<>)
            .MakeGenericType(resultType)
            .GetMethod(nameof(Result<object>.Failure), [typeof(Error)]);

        return (TResponse)failureMethod!.Invoke(null, [error])!;
    }
}
```

### 4. Entity Framework Core Mappings (Domain Modeling)

```csharp
// Infrastructure/Persistence/Configurations/OrderConfiguration.cs
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.ToTable("Orders");

        builder.HasKey(o => o.Id);

        builder.Property(o => o.CustomerId)
            .IsRequired();

        // Value Object mapping as Owned Entity
        builder.OwnsOne(o => o.ShippingAddress, addressBuilder =>
        {
            addressBuilder.Property(a => a.Street).HasMaxLength(150).IsRequired();
            addressBuilder.Property(a => a.City).HasMaxLength(100).IsRequired();
            addressBuilder.Property(a => a.PostalCode).HasMaxLength(20).IsRequired();
            addressBuilder.Property(a => a.Country).HasMaxLength(50).IsRequired();
        });

        // Navigation collection to child items
        builder.HasMany(o => o.Items)
            .WithOne()
            .HasForeignKey("OrderId")
            .IsRequired()
            .OnDelete(DeleteBehavior.Cascade);
    }
}
```

### 5. Production Testing with WebApplicationFactory & Respawn

```csharp
// Tests/Integration/IntegrationTestWebAppFactory.cs
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

public class IntegrationTestWebAppFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));

            if (descriptor != null)
            {
                services.Remove(descriptor);
            }

            services.AddDbContext<AppDbContext>(options =>
            {
                options.UseInMemoryDatabase("InMemoryIntegrationDb");
            });
        });
    }
}
```
