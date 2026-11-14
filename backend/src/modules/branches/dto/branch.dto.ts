import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateBranchDto {
  @ApiProperty({ example: 'RWWKD', description: 'Unique uppercase branch code' })
  @IsString()
  @IsNotEmpty()
  code: string;

  @ApiProperty({ example: 'RedWing Wakad', description: 'Branch display name' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: 'Dutt Mandir Rd, Wakad, Pune - 411057', description: 'Physical address' })
  @IsString()
  @IsNotEmpty()
  address: string;

  @ApiProperty({ example: 'Active', required: false })
  @IsString()
  @IsOptional()
  status?: string;
}

export class UpdateBranchDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiProperty({ example: 'Active | Inactive', required: false })
  @IsString()
  @IsOptional()
  status?: string;
}
