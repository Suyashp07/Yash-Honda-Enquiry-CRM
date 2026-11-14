import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Role } from '@prisma/client';

@Injectable()
export class BranchAccessGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user) {
      throw new ForbiddenException('User is not authenticated');
    }

    // Super Admin has full unrestricted access across all 6 branches
    if (user.role === Role.SUPER_ADMIN) {
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
