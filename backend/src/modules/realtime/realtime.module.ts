import { Global, Module } from '@nestjs/common';
import { FloorDashboardGateway } from './floor-dashboard.gateway';

@Global()
@Module({
  providers: [FloorDashboardGateway],
  exports: [FloorDashboardGateway],
})
export class RealtimeModule {}
