import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsEmail } from 'class-validator';

export class SendWhatsAppDto {
  @ApiProperty({ example: 'enquiryId' })
  @IsString()
  @IsNotEmpty()
  enquiryId: string;

  @ApiProperty({ example: 'quotation_send', description: 'Meta pre-approved template name' })
  @IsString()
  @IsNotEmpty()
  templateName: string;

  @ApiProperty({ example: 'quotationId', required: false })
  @IsString()
  @IsOptional()
  quotationId?: string;
}

export class SendEmailDto {
  @ApiProperty({ example: 'enquiryId' })
  @IsString()
  @IsNotEmpty()
  enquiryId: string;

  @ApiProperty({ example: 'customer@gmail.com' })
  @IsEmail()
  @IsNotEmpty()
  recipientEmail: string;

  @ApiProperty({ example: 'Your Yash Honda Official Quotation' })
  @IsString()
  @IsNotEmpty()
  subject: string;

  @ApiProperty({ example: 'quotationId', required: false })
  @IsString()
  @IsOptional()
  quotationId?: string;
}

