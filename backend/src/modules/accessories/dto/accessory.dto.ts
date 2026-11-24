import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsNumber, IsBoolean } from 'class-validator';

export class CreateAccessoryDto {
  @ApiProperty({ example: 'Ceramic Coating (2-Year)' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: 3500 })
  @IsNumber()
  defaultPrice: number;

  @ApiProperty({ example: true, description: 'false = FIX tag, true = rep can edit amount at POS' })
  @IsBoolean()
  @IsOptional()
  isPriceEditable?: boolean;

  @ApiProperty({ example: false, description: 'true = included as standard in Build My Honda, false = optional' })
  @IsBoolean()
  @IsOptional()
  isStandard?: boolean;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  imageUrl?: string | null;

  @ApiProperty({ example: 0, required: false })
  @IsNumber()
  @IsOptional()
  sortOrder?: number;
}

export class UpdateAccessoryDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  defaultPrice?: number;

  @ApiProperty({ required: false })
  @IsBoolean()
  @IsOptional()
  isPriceEditable?: boolean;

  @ApiProperty({ required: false })
  @IsBoolean()
  @IsOptional()
  isStandard?: boolean;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  imageUrl?: string | null;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  sortOrder?: number;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  status?: string;
}
