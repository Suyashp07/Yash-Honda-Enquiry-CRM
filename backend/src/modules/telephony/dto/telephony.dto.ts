import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class InitiateCallDto {
  @ApiProperty({ example: 'enquiryId' })
  @IsString()
  @IsNotEmpty()
  enquiryId: string;
}
