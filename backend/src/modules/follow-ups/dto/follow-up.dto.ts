import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsDateString } from 'class-validator';

export class CreateFollowUpDto {
  @ApiProperty({ example: 'enquiryId' })
  @IsString()
  @IsNotEmpty()
  enquiryId: string;

  @ApiProperty({ example: '2026-11-15T10:00:00.000Z' })
  @IsDateString()
  @IsNotEmpty()
  scheduledAt: string;

  @ApiProperty({ example: 'Follow up on loan document collection', required: false })
  @IsString()
  @IsOptional()
  remarks?: string;
}

export class CompleteFollowUpDto {
  @ApiProperty({ example: 'Customer confirmed visiting branch tomorrow at 4 PM', required: false })
  @IsString()
  @IsOptional()
  remarks?: string;
}

