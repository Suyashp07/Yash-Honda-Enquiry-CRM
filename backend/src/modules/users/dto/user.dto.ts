import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, Matches, MinLength, IsEnum, IsArray } from 'class-validator';
import { Role } from '@prisma/client';

export class CreateUserDto {
  @ApiProperty({ example: 'Suresh Patil' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: '9123456780' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^[0-9]{10}$/, { message: 'Mobile must be a valid 10-digit number' })
  mobile: string;

  @ApiProperty({ example: 'Password@123' })
  @IsString()
  @IsNotEmpty()
  @MinLength(6)
  password: string;

  @ApiProperty({ enum: Role, example: Role.SALES_EXEC })
  @IsEnum(Role)
  role: Role;

  @ApiProperty({ type: [String], example: ['branchId1', 'branchId2'], description: 'Assigned branch IDs' })
  @IsArray()
  @IsNotEmpty()
  branchIds: string[];
}

export class UpdateUserDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MinLength(6)
  password?: string;

  @ApiProperty({ enum: Role, required: false })
  @IsEnum(Role)
  @IsOptional()
  role?: Role;

  @ApiProperty({ example: 'Active | Inactive', required: false })
  @IsString()
  @IsOptional()
  status?: string;

  @ApiProperty({ type: [String], required: false })
  @IsArray()
  @IsOptional()
  branchIds?: string[];
}
