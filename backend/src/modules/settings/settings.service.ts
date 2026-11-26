import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateSettingsDto } from './dto/settings.dto';

const OFFICE_HOURS_SCOPE_KEY = 'config:office_hours';
const DEFAULT_OFFICE_WINDOWS = [
  { startTime: '9:00 AM', endTime: '1:00 PM', enabled: true },
  { startTime: '2:00 PM', endTime: '9:00 PM', enabled: true },
];

@Injectable()
export class SettingsService {
  constructor(private prisma: PrismaService) {}

  private async readOfficeHours() {
    try {
      const cached = await this.prisma.aiSummaryCache.findUnique({
        where: { scopeKey: OFFICE_HOURS_SCOPE_KEY },
      });
      if (cached?.summaryText) {
        const parsed = JSON.parse(cached.summaryText);
        return {
          officeHoursEnabled: Boolean(parsed.officeHoursEnabled),
          officeWindows: Array.isArray(parsed.officeWindows)
            ? parsed.officeWindows
            : DEFAULT_OFFICE_WINDOWS,
        };
      }
    } catch (_) {}
    return {
      officeHoursEnabled: false,
      officeWindows: DEFAULT_OFFICE_WINDOWS,
    };
  }

  async getSettings() {
    let existing = await this.prisma.companySettings.findFirst();
    if (!existing) {
      existing = await this.prisma.companySettings.create({
        data: {
          companyName: 'Yash Honda Two-Wheelers Pvt Ltd',
          hypothecationCharge: 0,
          applyHypothecationDefault: true,
        },
      });
    }
    const officeHours = await this.readOfficeHours();
    return {
      ...existing,
      ...officeHours,
    };
  }

  async updateSettings(dto: UpdateSettingsDto) {
    const existing = await this.prisma.companySettings.findFirst() ??
      await this.prisma.companySettings.create({
        data: {
          companyName: 'Yash Honda Two-Wheelers Pvt Ltd',
          hypothecationCharge: 0,
          applyHypothecationDefault: true,
        },
      });

    const { quotationTerms, officeHoursEnabled, officeWindows, ...data } = dto as any;
    const updated = await this.prisma.companySettings.update({
      where: { id: existing.id },
      data,
    });

    if (officeHoursEnabled !== undefined || officeWindows !== undefined) {
      const current = await this.readOfficeHours();
      const nextPayload = {
        officeHoursEnabled:
          officeHoursEnabled !== undefined
            ? Boolean(officeHoursEnabled)
            : current.officeHoursEnabled,
        officeWindows: Array.isArray(officeWindows)
          ? officeWindows
          : current.officeWindows,
      };
      await this.prisma.aiSummaryCache.upsert({
        where: { scopeKey: OFFICE_HOURS_SCOPE_KEY },
        update: {
          summaryText: JSON.stringify(nextPayload),
          generatedAt: new Date(),
        },
        create: {
          scopeKey: OFFICE_HOURS_SCOPE_KEY,
          summaryText: JSON.stringify(nextPayload),
        },
      });
    }

    const officeHours = await this.readOfficeHours();
    return {
      ...updated,
      ...officeHours,
    };
  }

  async updateBranding(type: string, url: string) {
    const existing = await this.getSettings();
    const data: any = {};
    if (type === 'logo') {
      data.logoUrl = url;
    } else {
      data.upiQrUrl = url;
    }
    return this.prisma.companySettings.update({
      where: { id: existing.id },
      data,
    });
  }

  async removeBranding(type: string) {
    const existing = await this.getSettings();
    const data: any = {};
    if (type === 'logo') {
      data.logoUrl = null;
    } else {
      data.upiQrUrl = null;
    }
    return this.prisma.companySettings.update({
      where: { id: existing.id },
      data,
    });
  }
}

