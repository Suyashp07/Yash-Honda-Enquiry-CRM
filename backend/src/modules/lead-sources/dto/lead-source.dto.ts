import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateLeadSourceDto {
  @ApiProperty({ example: 'Walk-in Showroom' })
  @IsString()
  @IsNotEmpty()
  name: string;
}

export class UpdateLeadSourceDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  status?: string;
}
