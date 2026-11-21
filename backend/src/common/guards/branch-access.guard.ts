import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class BranchAccessGuard implements CanActivate {
  constructor(private reflector?: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    if (this.reflector) {
      const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
        context.getHandler(),
        context.getClass(),
      ]);
      if (isPublic) {
        return true;
      }
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user) {
      throw new ForbiddenException('User is not authenticated');
    }

    // Super Admin has full unrestricted access across all 6 branches
    if (user.role === Role.SUPER_ADMIN || user.role === Role.OWNER) {
      return true;
    }

    // Extract target branchId from params, query, or body
    const branchId =
      request.params?.branchId ||
      request.query?.branchId ||
      request.body?.branchId;

    // If no branchId is specified in the request context, allow through
    // (route handler can perform record-specific branch check if needed)
    if (!branchId) {
      return true;
    }

    const assignedBranchIds: string[] = user.assignedBranchIds || [];
    const hasBranchAccess = assignedBranchIds.includes(branchId);

    if (!hasBranchAccess) {
      throw new ForbiddenException('Access denied: You are not assigned to this branch');
    }

    return true;
  }
}

