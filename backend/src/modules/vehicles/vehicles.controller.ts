import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, UseInterceptors, UploadedFile, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery, ApiConsumes } from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { existsSync, mkdirSync } from 'fs';
import { VehiclesService } from './vehicles.service';
import { CreateVehicleDto, UpdateVehicleDto, CreateModelGroupDto, UpdateModelGroupDto, CreateColourDto, UpdateColourDto } from './dto/vehicle.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';

@ApiTags('vehicles')
@Controller('vehicles')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class VehiclesController {
  constructor(private readonly vehiclesService: VehiclesService) {}

  @Get()
  @ApiOperation({ summary: 'List vehicles with optional category filter (MC | Scooter | BigBike)' })
  @ApiQuery({ name: 'category', required: false, enum: ['MC', 'Scooter', 'BigBike'] })
  findAllVehicles(@Query('category') category?: string) {
    return this.vehiclesService.findAllVehicles(category);
  }

  @Get('model-groups')
  @ApiOperation({ summary: 'List all model groups (RedWing, BigWing)' })
  findAllModelGroups() {
    return this.vehiclesService.findAllModelGroups();
  }

  @Post('model-groups')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Create model group (Super Admin only)' })
  createModelGroup(@Body() dto: CreateModelGroupDto) {
    return this.vehiclesService.createModelGroup(dto);
  }

  @Put('model-groups/:id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update model group (Super Admin only)' })
  updateModelGroup(@Param('id') id: string, @Body() dto: UpdateModelGroupDto) {
    return this.vehiclesService.updateModelGroup(id, dto);
  }

  @Delete('model-groups/:id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Deactivate model group (Super Admin only)' })
  removeModelGroup(@Param('id') id: string) {
    return this.vehiclesService.removeModelGroup(id);
  }

  @Get('colours')
  @ApiOperation({ summary: 'List all available colours' })
  findAllColours() {
    return this.vehiclesService.findAllColours();
  }

  @Post('colours')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Create new colour (Super Admin only)' })
  createColour(@Body() dto: CreateColourDto) {
    return this.vehiclesService.createColour(dto);
  }

  @Put('colours/:id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update colour (Super Admin only)' })
  updateColour(@Param('id') id: string, @Body() dto: UpdateColourDto) {
    return this.vehiclesService.updateColour(id, dto);
  }

  @Delete('colours/:id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Deactivate colour (Super Admin only)' })
  removeColour(@Param('id') id: string) {
    return this.vehiclesService.removeColour(id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get vehicle details by ID' })
  findOneVehicle(@Param('id') id: string) {
    return this.vehiclesService.findOneVehicle(id);
  }

  @Post()
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Create vehicle master (Super Admin only)' })
  createVehicle(@Body() dto: CreateVehicleDto) {
    return this.vehiclesService.createVehicle(dto);
  }

  @Put(':id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update vehicle master & on-road pricing (Super Admin only)' })
  updateVehicle(@Param('id') id: string, @Body() dto: UpdateVehicleDto) {
    return this.vehiclesService.updateVehicle(id, dto);
  }

  @Post(':id/brochure')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER)
  @ApiOperation({ summary: 'Upload or update vehicle brochure PDF / URL' })
  @ApiConsumes('multipart/form-data', 'application/json')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (req, file, cb) => {
          const uploadPath = join(process.cwd(), 'uploads', 'brochures');
          if (!existsSync(uploadPath)) {
            mkdirSync(uploadPath, { recursive: true });
          }
          cb(null, uploadPath);
        },
        filename: (req, file, cb) => {
          const ext = extname(file.originalname) || '.pdf';
          const cleanName = `brochure-${req.params.id}-${Date.now()}${ext}`;
          cb(null, cleanName);
        },
      }),
      limits: { fileSize: 30 * 1024 * 1024 }, // 30MB limit
    }),
  )
  async uploadBrochure(
    @Param('id') id: string,
    @UploadedFile() file?: any,
    @Body('url') manualUrl?: string,
  ) {
    const brochureUrl = file ? `/api/uploads/brochures/${file.filename}` : manualUrl;
    if (!brochureUrl) {
      throw new BadRequestException('Please provide a file or brochure URL');
    }
    return this.vehiclesService.updateVehicle(id, { brochureUrl });
  }

  @Delete(':id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Soft delete vehicle (Super Admin only)' })
  removeVehicle(@Param('id') id: string) {
    return this.vehiclesService.removeVehicle(id);
  }
}

