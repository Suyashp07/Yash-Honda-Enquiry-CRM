import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, Matches, IsDateString, IsEmail } from 'class-validator';

export class CreateCustomerDto {
  @ApiProperty({ example: 'Sachin Tendulkar' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: '9822012345' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^[0-9]{10}$/, { message: 'Mobile must be a 10-digit number' })
  mobile: string;

  @ApiProperty({ example: 'sachin@example.com', required: false })
  @IsEmail()
  @IsOptional()
  email?: string;

  @ApiProperty({ example: '1985-04-24T00:00:00.000Z', required: false })
  @IsDateString()
  @IsOptional()
  dob?: string;

  @ApiProperty({ example: '2010-12-10T00:00:00.000Z', required: false })
  @IsDateString()
  @IsOptional()
  anniversary?: string;

  @ApiProperty({ example: 'Flat 402, Green Acres, Wakad, Pune', required: false })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiProperty({ example: 'areaId', required: false })
  @IsString()
  @IsOptional()
  areaId?: string;
}

export class UpdateCustomerDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiProperty({ required: false })
  @IsEmail()
  @IsOptional()
  email?: string;

  @ApiProperty({ required: false })
  @IsDateString()
  @IsOptional()
  dob?: string;

  @ApiProperty({ required: false })
  @IsDateString()
  @IsOptional()
  anniversary?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  areaId?: string;
}

