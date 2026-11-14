import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateAreaDto {
  @ApiProperty({ example: 'Wakad' })
  @IsString()
  @IsNotEmpty()
  name: string;
}

export class UpdateAreaDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  status?: string;
}

