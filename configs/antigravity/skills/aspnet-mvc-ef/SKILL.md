---
name: aspnet-mvc-ef
description: Production conventions for ASP.NET Core Web API / MVC, Entity Framework Core (EF Core), generic repository pattern, dependency injection, and xUnit unit testing in C#. Use when building C# backends, controllers, services, database repositories, EF Core migrations, or writing xUnit tests.
---

# ASP.NET Core & Entity Framework Core Clean Architecture Guide

## When to use this skill
Trigger whenever building, refactoring, or testing ASP.NET Core Web APIs, MVC controllers, Entity Framework Core (EF Core) database layers, dependency injection setups, or writing xUnit tests in C#.

---

## 1. Architectural Layers & Boundaries

```
[HTTP Client] --> [Controller (DTOs only)]
                        |
                  [Domain Service (Business Invariants & Result<T,E>)]
                        |
                  [Generic IRepository<T> / IUnitOfWork]
                        |
                  [EF Core DbContext & SQL Database]
```

- **Controllers orchestrate only**: Never write business logic or query `DbContext` directly inside a controller.
- **DTOs at Boundaries**: Never return EF Core entity classes directly from controller actions.
- **Async Throughout**: All database queries and service calls must use `async/await` (`ToListAsync()`, `SaveChangesAsync()`).
- **Deep Reference Guide**: Consult [references/ef-core-patterns.md](references/ef-core-patterns.md) for DbContext pooling, `Result<T, E>` envelope types, `AsNoTracking` / `AsSplitQuery` patterns, and migration safety checklists.

---

## 2. Production C# Code Patterns

### A. Generic Repository Interface & EF Core Implementation
```csharp
// Core/Interfaces/IRepository.cs
using System;
using System.Collections.Generic;
using System.Linq.Expressions;
using System.Threading.Tasks;

public interface IRepository<T> where T : class
{
    Task<T?> GetByIdAsync(int id);
    Task<IReadOnlyList<T>> ListAllAsync();
    Task<IReadOnlyList<T>> ListAsync(Expression<Func<T, bool>> predicate);
    Task<T> AddAsync(T entity);
    Task UpdateAsync(T entity);
    Task DeleteAsync(T entity);
}

// Infrastructure/Data/EfRepository.cs
using Microsoft.EntityFrameworkCore;

public class EfRepository<T> : IRepository<T> where T : class
{
    protected readonly AppDbContext _dbContext;

    public EfRepository(AppDbContext dbContext)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
    }

    public async Task<T?> GetByIdAsync(int id)
    {
        return await _dbContext.Set<T>().FindAsync(id);
    }

    public async Task<IReadOnlyList<T>> ListAllAsync()
    {
        return await _dbContext.Set<T>().AsNoTracking().ToListAsync();
    }

    public async Task<IReadOnlyList<T>> ListAsync(Expression<Func<T, bool>> predicate)
    {
        return await _dbContext.Set<T>().Where(predicate).AsNoTracking().ToListAsync();
    }

    public async Task<T> AddAsync(T entity)
    {
        await _dbContext.Set<T>().AddAsync(entity);
        await _dbContext.SaveChangesAsync();
        return entity;
    }

    public async Task UpdateAsync(T entity)
    {
        _dbContext.Entry(entity).State = EntityState.Modified;
        await _dbContext.SaveChangesAsync();
    }

    public async Task DeleteAsync(T entity)
    {
        _dbContext.Set<T>().Remove(entity);
        await _dbContext.SaveChangesAsync();
    }
}
```

### B. Service Layer with DTOs
```csharp
// Core/Services/ProductService.cs
public class ProductService : IProductService
{
    private readonly IRepository<Product> _productRepo;

    public ProductService(IRepository<Product> productRepo)
    {
        _productRepo = productRepo;
    }

    public async Task<ProductDto?> GetProductByIdAsync(int id)
    {
        var entity = await _productRepo.GetByIdAsync(id);
        if (entity == null) return null;

        return new ProductDto
        {
            Id = entity.Id,
            Name = entity.Name,
            Price = entity.Price,
            Sku = entity.Sku
        };
    }
}
```

### C. Clean Web API Controller
```csharp
// Controllers/ProductsController.cs
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("api/v1/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly IProductService _productService;

    public ProductsController(IProductService productService)
    {
        _productService = productService;
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(ProductDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(int id)
    {
        var product = await _productService.GetProductByIdAsync(id);
        if (product == null)
        {
            return NotFound(new { message = $"Product with ID {id} not found." });
        }
        return Ok(product);
    }
}
```

---

## 3. Unit Testing Services with xUnit and Moq

```csharp
// tests/UnitTests/ProductServiceTests.cs
using System.Threading.Tasks;
using Xunit;
using Moq;
using FluentAssertions;

public class ProductServiceTests
{
    [Fact]
    public async Task GetProductByIdAsync_WhenFound_ReturnsMappedDto()
    {
        // Arrange
        var mockRepo = new Mock<IRepository<Product>>();
        var fakeProduct = new Product { Id = 1, Name = "Monitor", Price = 300m, Sku = "MON-1" };
        mockRepo.Setup(r => r.GetByIdAsync(1)).ReturnsAsync(fakeProduct);

        var service = new ProductService(mockRepo.Object);

        // Act
        var result = await service.GetProductByIdAsync(1);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be(1);
        result.Name.Should().Be("Monitor");
        mockRepo.Verify(r => r.GetByIdAsync(1), Times.Once);
    }
}
```

---

## 4. Verification & Testing

Validate build and test suites:
1. Build solution:
   ```bash
   dotnet build
   ```
2. Run xUnit tests:
   ```bash
   dotnet test
   ```
3. Verify EF Core migrations:
   ```bash
   dotnet ef migrations list
   ```

---

## 5. Things to Avoid

- Never inject `AppDbContext` directly into Controllers.
- Avoid sync-over-async code (`.Result` or `.Wait()`), which causes thread pool starvation.
- Never write direct SQL string concatenation (always use parameterized queries or EF Core LINQ).
- Avoid forgetting `.AsNoTracking()` on read-only queries.
