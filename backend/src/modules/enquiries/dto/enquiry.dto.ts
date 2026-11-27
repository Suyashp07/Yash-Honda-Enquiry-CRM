import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsEnum, ValidateNested, IsArray, IsNumber } from 'class-validator';
import { Type } from 'class-transformer';
import { EnquiryStatus } from '@prisma/client';
import { QuotationAccessoryInputDto } from '../../quotations/dto/quotation.dto';

export class CustomerInEnquiryDto {
  @ApiProperty({ example: 'Rohan Sharma' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: '9822987654' })
  @IsString()
  @IsNotEmpty()
  mobile: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  email?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  areaId?: string;
}

export class InitialQuotationInputDto {
  @ApiProperty({ example: 'vehicleId' })
  @IsString()
  @IsNotEmpty()
  vehicleId: string;

  @ApiProperty({ example: 'Pearl Siren Blue' })
  @IsString()
  @IsNotEmpty()
  colourName: string;

  @ApiProperty({ type: [QuotationAccessoryInputDto], required: false })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => QuotationAccessoryInputDto)
  @IsOptional()
  accessories?: QuotationAccessoryInputDto[];

  @ApiProperty({ example: 500, required: false })
  @IsNumber()
  @IsOptional()
  hypothecationCharge?: number;
}

export class CreateEnquiryDto {
  @ApiProperty({ example: 'branchId' })
  @IsString()
  @IsNotEmpty()
  branchId: string;

  @ApiProperty({ type: CustomerInEnquiryDto, required: false })
  @ValidateNested()
  @Type(() => CustomerInEnquiryDto)
  @IsOptional()
  customer?: CustomerInEnquiryDto;

  @ApiProperty({ example: 'customerId', required: false })
  @IsString()
  @IsOptional()
  customerId?: string;

  @ApiProperty({ example: 'leadSourceId', required: false })
  @IsString()
  @IsOptional()
  leadSourceId?: string;

  @ApiProperty({ example: 'Walk-in', description: 'Walk-in | Tele | Online' })
  @IsString()
  @IsNotEmpty()
  enquiryType: string;

  @ApiProperty({ example: 'Finance', description: 'Cash | Finance' })
  @IsString()
  @IsNotEmpty()
  purchaseMode: string;

  @ApiProperty({ example: 'financierId', required: false })
  @IsString()
  @IsOptional()
  financierId?: string;

  @ApiProperty({ example: 'No', description: 'No | Yes | Yes & Print', required: false })
  @IsString()
  @IsOptional()
  exchange?: string;

  @ApiProperty({ example: 'Within 7 Days', required: false })
  @IsString()
  @IsOptional()
  buyingWhen?: string;

  @ApiProperty({ example: 'Customer interested in quick delivery', required: false })
  @IsString()
  @IsOptional()
  remarks?: string;

  @ApiProperty({ example: 'assignedToUserId', required: false })
  @IsString()
  @IsOptional()
  assignedToId?: string;

  @ApiProperty({ type: InitialQuotationInputDto, required: false, description: 'Unified flow: generates quotation atomically' })
  @ValidateNested()
  @Type(() => InitialQuotationInputDto)
  @IsOptional()
  quotation?: InitialQuotationInputDto;
}

export class UpdateEnquiryStatusDto {
  @ApiProperty({ enum: EnquiryStatus, example: EnquiryStatus.CUSTOMER_BOUGHT })
  @IsEnum(EnquiryStatus)
  @IsNotEmpty()
  status: EnquiryStatus;

  @ApiProperty({ example: 'Booking confirmed with receipt', required: false })
  @IsString()
  @IsOptional()
  remarks?: string;
}

export class AssignEnquiryDto {
  @ApiProperty({ example: 'targetSalesExecUserId' })
  @IsString()
  @IsNotEmpty()
  assignedToId: string;
}

