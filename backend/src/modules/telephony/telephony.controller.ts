import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { TelephonyService } from './telephony.service';
import { InitiateCallDto } from './dto/telephony.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('telephony')
@Controller('telephony')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class TelephonyController {
  constructor(private readonly telephonyService: TelephonyService) {}

  @Post('call')
  @ApiOperation({ summary: 'Initiate Exotel click-to-call mobile bridge between rep and customer' })
  initiateCall(@Body() dto: InitiateCallDto, @CurrentUser() user: any) {
    return this.telephonyService.initiateCall(dto, user);
  }

  @Get('calls')
  @ApiOperation({ summary: 'List customer call history logs for authorized branches' })
  @ApiQuery({ name: 'branchId', required: false })
  findAll(@CurrentUser() user: any, @Query('branchId') branchId?: string) {
    return this.telephonyService.findAll(user, branchId);
  }

  @Get('calls/:id/recording')
  @ApiOperation({ summary: 'Get secure Cloudflare R2 streaming URL for call recording playback' })
  getRecordingUrl(@Param('id') id: string, @CurrentUser() user: any) {
    return this.telephonyService.getRecordingUrl(id, user);
  }
}

