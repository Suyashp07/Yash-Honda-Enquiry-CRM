import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateVehicleDto, UpdateVehicleDto, CreateModelGroupDto, UpdateModelGroupDto, CreateColourDto, UpdateColourDto } from './dto/vehicle.dto';

@Injectable()
export class VehiclesService {
  constructor(private prisma: PrismaService) {}

  // Vehicles
  async findAllVehicles(category?: string) {
    return this.prisma.vehicle.findMany({
      where: category ? { category, status: 'Active' } : undefined,
      include: {
        modelGroup: true,
        colours: {
          include: {
            colour: true,
          },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  async findOneVehicle(id: string) {
    const vehicle = await this.prisma.vehicle.findUnique({
      where: { id },
      include: {
        modelGroup: true,
        colours: {
          include: {
            colour: true,
          },
        },
      },
    });
    if (!vehicle) {
      throw new NotFoundException(`Vehicle with ID ${id} not found`);
    }
    return vehicle;
  }

  async createVehicle(dto: CreateVehicleDto) {
    const existing = await this.prisma.vehicle.findUnique({
      where: { code: dto.code },
    });
    if (existing) {
      throw new ConflictException(`Vehicle with code ${dto.code} already exists`);
    }

    const { colourIds, ...data } = dto;
    return this.prisma.$transaction(async (tx) => {
      const vehicle = await tx.vehicle.create({
        data,
      });

      if (colourIds && colourIds.length > 0) {
        await tx.vehicleColour.createMany({
          data: colourIds.map((cid) => ({
            vehicleId: vehicle.id,
            colourId: cid,
          })),
        });
      }

      return tx.vehicle.findUnique({
        where: { id: vehicle.id },
        include: { modelGroup: true, colours: { include: { colour: true } } },
      });
    });
  }

  async updateVehicle(id: string, dto: UpdateVehicleDto) {
    await this.findOneVehicle(id);
    const { colourIds, ...data } = dto;

    return this.prisma.$transaction(async (tx) => {
      const vehicle = await tx.vehicle.update({
        where: { id },
        data,
      });

      if (colourIds !== undefined) {
        await tx.vehicleColour.deleteMany({
          where: { vehicleId: id },
        });

        if (colourIds.length > 0) {
          await tx.vehicleColour.createMany({
            data: colourIds.map((cid) => ({
              vehicleId: id,
              colourId: cid,
            })),
          });
        }
      }

      return tx.vehicle.findUnique({
        where: { id },
        include: { modelGroup: true, colours: { include: { colour: true } } },
      });
    });
  }

  async removeVehicle(id: string) {
    await this.findOneVehicle(id);
    return this.prisma.vehicle.update({
      where: { id },
      data: { status: 'Inactive' },
    });
  }

  // Model Groups
  async findAllModelGroups() {
    return this.prisma.modelGroup.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async createModelGroup(dto: CreateModelGroupDto) {
    return this.prisma.modelGroup.create({
      data: dto,
    });
  }

  async updateModelGroup(id: string, dto: UpdateModelGroupDto) {
    return this.prisma.modelGroup.update({
      where: { id },
      data: dto,
    });
  }

  async removeModelGroup(id: string) {
    return this.prisma.modelGroup.update({
      where: { id },
      data: { status: 'Inactive' },
    });
  }

  // Colours
  async findAllColours() {
    return this.prisma.colour.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async createColour(dto: CreateColourDto) {
    return this.prisma.colour.create({
      data: dto,
    });
  }

  async updateColour(id: string, dto: UpdateColourDto) {
    return this.prisma.colour.update({
      where: { id },
      data: dto,
    });
  }

  async removeColour(id: string) {
    return this.prisma.colour.update({
      where: { id },
      data: { status: 'Inactive' },
    });
  }
}

