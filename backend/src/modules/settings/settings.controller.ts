import { Controller, Get, Put, Post, Delete, Body, Param, UseGuards, UseInterceptors, UploadedFile, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { existsSync, mkdirSync, readFileSync } from 'fs';
import { SettingsService } from './settings.service';
import { UpdateSettingsDto } from './dto/settings.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';

@ApiTags('settings')
@Controller('settings')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get()
  @ApiOperation({ summary: 'Get dealership profile and quotation default settings' })
  getSettings() {
    return this.settingsService.getSettings();
  }

  @Put()
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update dealership settings (Super Admin only)' })
  updateSettings(@Body() dto: UpdateSettingsDto) {
    return this.settingsService.updateSettings(dto);
  }

  @Post('upload/:type')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Upload branding logo or UPI QR code image (Super Admin only)' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (req, file, cb) => {
          const uploadPath = join(process.cwd(), 'uploads', 'branding');
          if (!existsSync(uploadPath)) {
            mkdirSync(uploadPath, { recursive: true });
          }
          cb(null, uploadPath);
        },
        filename: (req, file, cb) => {
          const ext = extname(file.originalname) || '.png';
          const type = req.params.type === 'logo' ? 'logo' : 'upi-qr';
          const cleanName = `${type}-${Date.now()}${ext}`;
          cb(null, cleanName);
        },
      }),
      limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
    }),
  )
  async uploadBranding(
    @Param('type') type: string,
    @UploadedFile() file?: any,
  ) {
    if (!file) {
      throw new BadRequestException('Please provide an image file');
    }
    const normalizedType = type === 'logo' ? 'logo' : 'upi-qr';

    let dataUri = '';
    try {
      if (file.path && existsSync(file.path)) {
        const buf = readFileSync(file.path);
        const mime = file.mimetype || (normalizedType === 'logo' ? 'image/png' : 'image/png');
        dataUri = `data:${mime};base64,${buf.toString('base64')}`;
      }
    } catch (e) {
      console.warn('Could not encode uploaded branding to data URI:', e);
    }

    const brandingUrl = dataUri || `/api/uploads/branding/${file.filename}`;
    const updated = await this.settingsService.updateBranding(normalizedType, brandingUrl);
    return {
      success: true,
      url: brandingUrl,
      type: normalizedType,
      settings: updated,
    };
  }

  @Delete('branding/:type')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Remove branding logo or UPI QR code image (Super Admin only)' })
  async removeBranding(@Param('type') type: string) {
    const normalizedType = type === 'logo' ? 'logo' : 'upi-qr';
    const updated = await this.settingsService.removeBranding(normalizedType);
    return {
      success: true,
      type: normalizedType,
      settings: updated,
    };
  }
}

