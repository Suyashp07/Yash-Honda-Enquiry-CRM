import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../../prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private configService: ConfigService,
    private prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        ExtractJwt.fromAuthHeaderAsBearerToken(),
        ExtractJwt.fromUrlQueryParameter('token'),
      ]),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET') || 'super-secret-jwt-key',
    });
  }

  async validate(payload: { sub: string; mobile: string; role: string }) {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: {
        userBranches: {
          include: {
            branch: {
              select: {
                id: true,
                code: true,
                name: true,
                status: true,
              },
            },
          },
        },
      },
    });

    if (!user || user.status !== 'Active') {
      throw new UnauthorizedException('User account is inactive or not found');
    }

    const assignedBranchIds = user.userBranches
      .filter((ub) => ub.branch.status === 'Active')
      .map((ub) => ub.branch.id);

    const assignedBranches = user.userBranches
      .filter((ub) => ub.branch.status === 'Active')
      .map((ub) => ub.branch);

    return {
      id: user.id,
      name: user.name,
      mobile: user.mobile,
      role: user.role,
      assignedBranchIds,
      assignedBranches,
    };
  }
}

