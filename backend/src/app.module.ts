import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { BranchesModule } from './modules/branches/branches.module';
import { UsersModule } from './modules/users/users.module';
import { VehiclesModule } from './modules/vehicles/vehicles.module';
import { AccessoriesModule } from './modules/accessories/accessories.module';
import { FinanciersModule } from './modules/financiers/financiers.module';
import { AreasModule } from './modules/areas/areas.module';
import { LeadSourcesModule } from './modules/lead-sources/lead-sources.module';
import { SettingsModule } from './modules/settings/settings.module';
import { CustomersModule } from './modules/customers/customers.module';
import { QuotationsModule } from './modules/quotations/quotations.module';
import { EnquiriesModule } from './modules/enquiries/enquiries.module';
import { FollowUpsModule } from './modules/follow-ups/follow-ups.module';
import { TelephonyModule } from './modules/telephony/telephony.module';
import { CommunicationsModule } from './modules/communications/communications.module';
import { WebhooksModule } from './modules/webhooks/webhooks.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { AiInsightsModule } from './modules/ai-insights/ai-insights.module';
import { ReportsModule } from './modules/reports/reports.module';
import { AuditModule } from './modules/audit/audit.module';
import { RealtimeModule } from './modules/realtime/realtime.module';
import { JobsModule } from './modules/jobs/jobs.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    PrismaModule,
    AuditModule,
    RealtimeModule,
    JobsModule,
    AuthModule,
    BranchesModule,
    UsersModule,
    VehiclesModule,
    AccessoriesModule,
    FinanciersModule,
    AreasModule,
    LeadSourcesModule,
    SettingsModule,
    CustomersModule,
    QuotationsModule,
    EnquiriesModule,
    FollowUpsModule,
    TelephonyModule,
    CommunicationsModule,
    WebhooksModule,
    AnalyticsModule,
    AiInsightsModule,
    ReportsModule,
  ],
})
export class AppModule {}
