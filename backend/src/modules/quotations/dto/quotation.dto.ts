import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsNumber, IsArray, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class QuotationAccessoryInputDto {
  @ApiProperty({ example: 'accessoryId' })
  @IsString()
  @IsNotEmpty()
  accessoryId: string;

  @ApiProperty({ example: 1250, required: false, description: 'Overridden price if accessory is editable' })
  @IsNumber()
  @IsOptional()
  amount?: number;
}

export class CalculateQuotationDto {
  @ApiProperty({ example: 'vehicleId' })
  @IsString()
  @IsNotEmpty()
  vehicleId: string;

  @ApiProperty({ example: 'branchId' })
  @IsString()
  @IsNotEmpty()
  branchId: string;

  @ApiProperty({ example: 'Pearl Siren Blue' })
  @IsString()
  @IsNotEmpty()
  colourName: string;

  @ApiProperty({ example: 'Finance', description: 'Cash | Finance' })
  @IsString()
  @IsNotEmpty()
  purchaseMode: string;

  @ApiProperty({ type: [QuotationAccessoryInputDto], required: false })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => QuotationAccessoryInputDto)
  @IsOptional()
  accessories?: QuotationAccessoryInputDto[];
}

export class CreateQuotationDto extends CalculateQuotationDto {
  @ApiProperty({ example: 'enquiryId' })
  @IsString()
  @IsNotEmpty()
  enquiryId: string;
}
