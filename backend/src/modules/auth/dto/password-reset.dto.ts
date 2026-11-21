import { IsNotEmpty, IsString, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ForgotPasswordDto {
  @ApiProperty({ example: '9999999999', description: 'Registered 10-digit mobile number' })
  @IsNotEmpty()
  @IsString()
  mobile: string;
}

export class ResetPasswordDto {
  @ApiProperty({ example: '9999999999', description: 'Registered 10-digit mobile number' })
  @IsNotEmpty()
  @IsString()
  mobile: string;

  @ApiProperty({ example: '123456', description: '6-digit OTP' })
  @IsNotEmpty()
  @IsString()
  otp: string;

  @ApiProperty({ example: 'NewPassword@2026', description: 'New password' })
  @IsNotEmpty()
  @IsString()
  @MinLength(6)
  newPassword: string;
}
