import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { AccessoriesService } from './accessories.service';
import { CreateAccessoryDto, UpdateAccessoryDto } from './dto/accessory.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { processUploadedImage } from '../../common/utils/image-processor';
import { Role } from '@prisma/client';

@ApiTags('accessories')
@Controller('accessories')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class AccessoriesController {
  constructor(private readonly accessoriesService: AccessoriesService) {}

  @Get()
  @ApiOperation({ summary: 'List all accessories with standard/optional & image fields' })
  findAll() {
    return this.accessoriesService.findAll();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get accessory details by ID' })
  findOne(@Param('id') id: string) {
    return this.accessoriesService.findOne(id);
  }

  @Post()
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Create new accessory (Super Admin only)' })
  create(@Body() dto: CreateAccessoryDto) {
    return this.accessoriesService.create(dto);
  }

  @Put(':id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update accessory (Super Admin only)' })
  update(@Param('id') id: string, @Body() dto: UpdateAccessoryDto) {
    return this.accessoriesService.update(id, dto);
  }

  @Post(':id/image')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Upload & Sharp-validate thumbnail image for accessory' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  async uploadImage(
    @Param('id') id: string,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    const processed = await processUploadedImage(file, 'accessory');
    const accessory = await this.accessoriesService.updateImage(id, processed.dataUri);
    return {
      success: true,
      url: processed.dataUri,
      quality: {
        width: processed.width,
        height: processed.height,
        originalWidth: processed.originalWidth,
        originalHeight: processed.originalHeight,
        sizeKb: processed.sizeKb,
        qualityScore: processed.qualityScore,
        warnings: processed.warnings,
      },
      accessory,
    };
  }

  @Delete(':id/image')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Remove thumbnail image from accessory' })
  async removeImage(@Param('id') id: string) {
    const accessory = await this.accessoriesService.updateImage(id, null);
    return { success: true, accessory };
  }

  @Delete(':id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Soft delete accessory (Super Admin only)' })
  remove(@Param('id') id: string) {
    return this.accessoriesService.remove(id);
  }
}
