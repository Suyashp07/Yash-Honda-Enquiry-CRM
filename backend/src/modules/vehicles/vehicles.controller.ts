import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { VehiclesService } from './vehicles.service';
import { CreateVehicleDto, UpdateVehicleDto, CreateModelGroupDto, CreateColourDto } from './dto/vehicle.dto';
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

  @Delete(':id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Soft delete vehicle (Super Admin only)' })
  removeVehicle(@Param('id') id: string) {
    return this.vehiclesService.removeVehicle(id);
  }
}

