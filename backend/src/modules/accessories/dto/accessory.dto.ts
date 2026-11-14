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
  @IsString()
  @IsOptional()
  status?: string;
}

