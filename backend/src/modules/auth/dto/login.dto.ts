import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Matches, MinLength } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: '9999999999', description: 'Staff 10-digit mobile number' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^[0-9]{10}$/, { message: 'Mobile must be a valid 10-digit phone number' })
  mobile: string;

  @ApiProperty({ example: 'YashHonda@2026', description: 'Staff account password' })
  @IsString()
  @IsNotEmpty()
  @MinLength(6)
  password: string;
}

