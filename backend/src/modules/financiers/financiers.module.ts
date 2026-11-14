import { Module } from '@nestjs/common';
import { FinanciersService } from './financiers.service';
import { FinanciersController } from './financiers.controller';

@Module({
  controllers: [FinanciersController],
  providers: [FinanciersService],
  exports: [FinanciersService],
})
export class FinanciersModule {}

