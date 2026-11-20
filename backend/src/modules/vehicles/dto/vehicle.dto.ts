import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsNumber, IsArray } from 'class-validator';

export class CreateModelGroupDto {
  @ApiProperty({ example: 'RedWing' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: 'RWQ' })
  @IsString()
  @IsNotEmpty()
  quotePrefix: string;
}

export class UpdateModelGroupDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  quotePrefix?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  status?: string;
}

export class CreateColourDto {
  @ApiProperty({ example: 'Pearl Siren Blue' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: '#1E3A8A' })
  @IsString()
  @IsNotEmpty()
  hex: string;
}

export class UpdateColourDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  hex?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  status?: string;
}

export class CreateVehicleDto {
  @ApiProperty({ example: 'ACT6G' })
  @IsString()
  @IsNotEmpty()
  code: string;

  @ApiProperty({ example: 'Activa 6G DLX' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: 'Scooter', description: 'MC | Scooter | BigBike' })
  @IsString()
  @IsNotEmpty()
  category: string;

  @ApiProperty({ example: 'modelGroupId' })
  @IsString()
  @IsNotEmpty()
  modelGroupId: string;

  @ApiProperty({ example: 79000 })
  @IsNumber()
  exShowroomPrice: number;

  @ApiProperty({ example: 94500, description: 'Manually maintained on-road price in Pune' })
  @IsNumber()
  onRoadPrice: number;

  @ApiProperty({ type: [String], example: ['colourId1', 'colourId2'], required: false })
  @IsArray()
  @IsOptional()
  colourIds?: string[];

  @ApiProperty({ example: 'https://example.com/activa-brochure.pdf', required: false })
  @IsString()
  @IsOptional()
  brochureUrl?: string;
}

export class UpdateVehicleDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  category?: string;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  exShowroomPrice?: number;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  onRoadPrice?: number;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  brochureUrl?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  status?: string;

  @ApiProperty({ type: [String], required: false })
  @IsArray()
  @IsOptional()
  colourIds?: string[];
}

