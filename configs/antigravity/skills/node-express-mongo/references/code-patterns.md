# Node.js, Express & Mongoose Reference Patterns

## Full Repository & Controller Patterns

```ts
// src/features/users/user.repository.ts
import { UserModel, type IUserDocument, type IUser } from './user.model';

export interface IUserRepository {
  findById(id: string): Promise<IUserDocument | null>;
  findByEmail(email: string): Promise<IUserDocument | null>;
  create(userData: Partial<IUser>): Promise<IUserDocument>;
  update(id: string, updateData: Partial<IUser>): Promise<IUserDocument | null>;
  delete(id: string): Promise<boolean>;
}

export class MongoUserRepository implements IUserRepository {
  async findById(id: string): Promise<IUserDocument | null> {
    return UserModel.findById(id).exec();
  }

  async findByEmail(email: string): Promise<IUserDocument | null> {
    return UserModel.findOne({ email: email.toLowerCase() }).exec();
  }

  async create(userData: Partial<IUser>): Promise<IUserDocument> {
    return UserModel.create(userData);
  }

  async update(id: string, updateData: Partial<IUser>): Promise<IUserDocument | null> {
    return UserModel.findByIdAndUpdate(id, updateData, { new: true, runValidators: true }).exec();
  }

  async delete(id: string): Promise<boolean> {
    const result = await UserModel.findByIdAndDelete(id).exec();
    return !!result;
  }
}
```
