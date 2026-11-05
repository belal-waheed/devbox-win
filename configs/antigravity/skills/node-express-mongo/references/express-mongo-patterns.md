# Express 5 & Mongoose Production Architecture Patterns

Production reference guide for building robust, scalable REST APIs using Express 5, TypeScript, Mongoose, and Zod edge validation.

---

## 1. Zod Edge Validation Middleware

Validate incoming request body, query parameters, and route params at the HTTP router boundary before requests reach business logic:

```typescript
// middleware/validate.ts
import { Request, Response, NextFunction } from 'express';
import { AnyZodObject, ZodError } from 'zod';

export function validate(schema: AnyZodObject) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const parsed = await schema.parseAsync({
        body: req.body,
        query: req.query,
        params: req.params,
      });

      req.body = parsed.body;
      req.query = parsed.query;
      req.params = parsed.params;
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        res.status(400).json({
          success: false,
          error: 'Validation failed',
          issues: error.issues.map((i) => ({
            field: i.path.join('.'),
            message: i.message,
          })),
        });
        return;
      }
      next(error);
    }
  };
}
```

---

## 2. Express 5 Native Async Error Handling & Central Error Handler

In Express 5, unhandled promise rejections in async route handlers are caught automatically and forwarded to error middleware:

```typescript
// middleware/error-handler.ts
import { Request, Response, NextFunction } from 'express';

export class AppError extends Error {
  constructor(
    public statusCode: number,
    public message: string,
    public isOperational = true
  ) {
    super(message);
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export function centralErrorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  if (err instanceof AppError && err.isOperational) {
    res.status(err.statusCode).json({
      success: false,
      error: err.message,
    });
    return;
  }

  // Unhandled / programmer errors
  console.error('[CRITICAL] Unhandled Server Error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
  });
}
```

---

## 3. Mongoose Schema Indexes & Schema Design

Enforce compound indexes and indexing strategies to support high-throughput read queries:

```typescript
// models/order.model.ts
import { Schema, model, Document, Types } from 'mongoose';

export interface IOrderItem {
  productId: Types.ObjectId;
  quantity: number;
  unitPrice: number;
}

export interface IOrder extends Document {
  customerId: Types.ObjectId;
  status: 'pending' | 'processing' | 'shipped' | 'cancelled';
  items: IOrderItem[];
  totalAmount: number;
  createdAt: Date;
  updatedAt: Date;
}

const OrderItemSchema = new Schema<IOrderItem>(
  {
    productId: { type: Schema.Types.ObjectId, required: true, ref: 'Product' },
    quantity: { type: Number, required: true, min: 1 },
    unitPrice: { type: Number, required: true, min: 0 },
  },
  { _id: false }
);

const OrderSchema = new Schema<IOrder>(
  {
    customerId: { type: Schema.Types.ObjectId, required: true, ref: 'Customer', index: true },
    status: {
      type: String,
      required: true,
      enum: ['pending', 'processing', 'shipped', 'cancelled'],
      default: 'pending',
    },
    items: { type: [OrderItemSchema], required: true },
    totalAmount: { type: Number, required: true, min: 0 },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

// Compound index for frequent customer order queries ordered by date
OrderSchema.index({ customerId: 1, createdAt: -1 });

export const OrderModel = model<IOrder>('Order', OrderSchema);
```

---

## 4. Generic Mongoose Base Repository

```typescript
// repositories/base.repository.ts
import { Model, Document, FilterQuery, UpdateQuery } from 'mongoose';

export interface IBaseRepository<T extends Document> {
  findById(id: string): Promise<T | null>;
  findOne(filter: FilterQuery<T>): Promise<T | null>;
  find(filter: FilterQuery<T>, limit?: number, skip?: number): Promise<T[]>;
  create(item: Partial<T>): Promise<T>;
  update(id: string, update: UpdateQuery<T>): Promise<T | null>;
  delete(id: string): Promise<boolean>;
}

export class BaseRepository<T extends Document> implements IBaseRepository<T> {
  constructor(protected readonly model: Model<T>) {}

  async findById(id: string): Promise<T | null> {
    return this.model.findById(id).lean<T>().exec();
  }

  async findOne(filter: FilterQuery<T>): Promise<T | null> {
    return this.model.findOne(filter).lean<T>().exec();
  }

  async find(filter: FilterQuery<T>, limit = 50, skip = 0): Promise<T[]> {
    return this.model.find(filter).skip(skip).limit(limit).lean<T[]>().exec();
  }

  async create(item: Partial<T>): Promise<T> {
    return this.model.create(item);
  }

  async update(id: string, update: UpdateQuery<T>): Promise<T | null> {
    return this.model.findByIdAndUpdate(id, update, { new: true, runValidators: true }).lean<T>().exec();
  }

  async delete(id: string): Promise<boolean> {
    const res = await this.model.findByIdAndDelete(id).exec();
    return !!res;
  }
}
```

---

## 5. Negative Constraints & Common Anti-Patterns

- **Never bypass Zod validation:** Never access `req.body` directly in controller or service without schema parsing.
- **Never perform unbounded database queries:** Always enforce pagination with `limit` and `skip`.
- **Avoid querying without indexes:** Use `.explain('executionStats')` on high-traffic queries to verify `IXSCAN`.
- **Never suppress asynchronous errors:** Express 5 automatically routes errors, but manual try/catch must re-pass unknown errors to `next(err)`.
