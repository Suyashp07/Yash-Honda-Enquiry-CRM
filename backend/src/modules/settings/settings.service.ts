import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateSettingsDto } from './dto/settings.dto';

@Injectable()
export class SettingsService {
  constructor(private prisma: PrismaService) {}

  async getSettings() {
    const existing = await this.prisma.companySettings.findFirst();
    if (!existing) {
      return this.prisma.companySettings.create({
        data: {
          companyName: 'Yash Honda Two-Wheelers Pvt Ltd',
          hypothecationCharge: 0,
          applyHypothecationDefault: true,
        },
      });
    }
    return existing;
  }

  async updateSettings(dto: UpdateSettingsDto) {
    const existing = await this.getSettings();
    return this.prisma.companySettings.update({
      where: { id: existing.id },
      data: dto,
    });
  }
}
