import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsNumber, IsBoolean } from 'class-validator';

export class UpdateSettingsDto {
  @ApiProperty({ example: 'Yash Honda Two-Wheelers Pvt Ltd' })
  @IsString()
  @IsOptional()
  companyName?: string;

  @ApiProperty({ example: '27AABCY1234F1Z5' })
  @IsString()
  @IsOptional()
  gstNumber?: string;

  @ApiProperty({ example: 'Plot 12, Pimpri-Chinchwad Ind Area, Pune - 411019' })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiProperty({ example: 'HDFC Bank Ltd' })
  @IsString()
  @IsOptional()
  bankName?: string;

  @ApiProperty({ example: '50200012345678' })
  @IsString()
  @IsOptional()
  accountNumber?: string;

  @ApiProperty({ example: 'HDFC0001234' })
  @IsString()
  @IsOptional()
  ifsc?: string;

  @ApiProperty({ example: 'yashhonda@hdfcbank' })
  @IsString()
  @IsOptional()
  upiId?: string;

  @ApiProperty({ example: 'Terms and conditions', required: false })
  @IsString()
  @IsOptional()
  quotationTerms?: string;

  @ApiProperty({ example: '/api/uploads/branding/logo.png', required: false })
  @IsString()
  @IsOptional()
  logoUrl?: string;

  @ApiProperty({ example: '/api/uploads/branding/upi-qr.png', required: false })
  @IsString()
  @IsOptional()
  upiQrUrl?: string;

  @ApiProperty({ example: 1500, description: 'Bank Hypothecation loan documentation charge' })
  @IsNumber()
  @IsOptional()
  hypothecationCharge?: number;

  @ApiProperty({ example: true })
  @IsBoolean()
  @IsOptional()
  applyHypothecationDefault?: boolean;
}

