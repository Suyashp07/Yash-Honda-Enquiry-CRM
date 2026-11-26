import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateVehicleDto,
  UpdateVehicleDto,
  CreateModelGroupDto,
  UpdateModelGroupDto,
  CreateColourDto,
  UpdateColourDto,
} from './dto/vehicle.dto';

@Injectable()
export class VehiclesService {
  constructor(private prisma: PrismaService) {}

  private normalizeCategory(raw: string | null | undefined, modelGroupName?: string): string {
    const low = (raw || '').toLowerCase();
    const mgLow = (modelGroupName || '').toLowerCase();
    if (low.includes('scooter')) return 'Scooter';
    if (low.includes('big') || low.includes('wing') || mgLow.includes('big')) return 'BigBike';
    return 'MC';
  }

  // Public bootstrap endpoint for Build My Honda (works logged-in OR unauthenticated kiosk)
  async getConfiguratorBootstrap(category?: string, cc?: number) {
    const [vehicles, accessories, financiers, branches, colours] = await Promise.all([
      this.prisma.vehicle.findMany({
        where: { status: 'Active' },
        include: {
          modelGroup: true,
          colours: { include: { colour: true } },
        },
        orderBy: [{ ccDisplacement: 'asc' }, { exShowroomPrice: 'asc' }],
      }),
      this.prisma.accessory.findMany({
        where: { status: 'Active' },
        orderBy: [{ isStandard: 'desc' }, { sortOrder: 'asc' }, { name: 'asc' }],
      }),
      this.prisma.financier.findMany({
        where: { status: 'Active' },
        orderBy: { name: 'asc' },
      }),
      this.prisma.branch.findMany({
        where: { status: 'Active' },
        select: { id: true, code: true, name: true, wing: true, address: true },
        orderBy: { name: 'asc' },
      }),
      this.prisma.colour.findMany({
        where: { status: 'Active' },
        orderBy: { name: 'asc' },
      }),
    ]);

    let filteredVehicles = vehicles.map((v) => ({
      ...v,
      normalizedCategory: this.normalizeCategory(v.category, v.modelGroup?.name),
    }));

    if (category) {
      filteredVehicles = filteredVehicles.filter(
        (v) => v.normalizedCategory.toLowerCase() === category.toLowerCase(),
      );
    }
    if (cc && Number.isFinite(cc)) {
      filteredVehicles = filteredVehicles.filter((v) => v.ccDisplacement === cc);
    }

    return {
      vehicles: filteredVehicles,
      accessories,
      financiers,
      branches,
      colours,
    };
  }

  // Vehicles
  async findAllVehicles(category?: string) {
    const list = await this.prisma.vehicle.findMany({
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
    return list;
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
      await tx.vehicle.update({
        where: { id },
        data,
      });

      if (colourIds !== undefined) {
        // Preserve existing per-colour uploaded images for retained colours
        const existingLinks = await tx.vehicleColour.findMany({
          where: { vehicleId: id },
        });
        const existingImagesByColourId = new Map<string, string | null>();
        for (const link of existingLinks) {
          existingImagesByColourId.set(link.colourId, link.colourImageUrl);
        }

        await tx.vehicleColour.deleteMany({
          where: { vehicleId: id },
        });

        if (colourIds.length > 0) {
          await tx.vehicleColour.createMany({
            data: colourIds.map((cid) => ({
              vehicleId: id,
              colourId: cid,
              colourImageUrl: existingImagesByColourId.get(cid) ?? null,
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

  async updateVehicleImage(id: string, slot: 'listing' | 'detail', imageUrl: string | null) {
    await this.findOneVehicle(id);
    const data = slot === 'listing' ? { listingImageUrl: imageUrl } : { detailImageUrl: imageUrl };
    return this.prisma.vehicle.update({
      where: { id },
      data,
      include: { modelGroup: true, colours: { include: { colour: true } } },
    });
  }

  async updateVehicleColourImage(vehicleId: string, colourId: string, colourImageUrl: string | null) {
    await this.findOneVehicle(vehicleId);
    const colour = await this.prisma.colour.findUnique({ where: { id: colourId } });
    if (!colour) {
      throw new NotFoundException(`Colour with ID ${colourId} not found`);
    }

    await this.prisma.vehicleColour.upsert({
      where: {
        vehicleId_colourId: { vehicleId, colourId },
      },
      update: { colourImageUrl },
      create: { vehicleId, colourId, colourImageUrl },
    });

    return this.findOneVehicle(vehicleId);
  }

  async removeVehicle(id: string) {
    await this.findOneVehicle(id);
    const [itemCount, quoteCount] = await Promise.all([
      this.prisma.quotationItem.count({ where: { vehicleId: id } }),
      this.prisma.quotation.count({ where: { vehicleId: id } }),
    ]);
    if (itemCount > 0 || quoteCount > 0) {
      throw new BadRequestException(
        'Cannot delete vehicle because it is used in existing quotations. Mark it Inactive instead.',
      );
    }
    return this.prisma.$transaction(async (tx) => {
      await tx.vehicleColour.deleteMany({ where: { vehicleId: id } });
      return tx.vehicle.delete({ where: { id } });
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
    const vehicleCount = await this.prisma.vehicle.count({
      where: { modelGroupId: id },
    });
    if (vehicleCount > 0) {
      throw new BadRequestException(
        'Cannot delete model group because it has linked vehicles. Mark it Inactive instead.',
      );
    }
    return this.prisma.modelGroup.delete({
      where: { id },
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
    return this.prisma.$transaction(async (tx) => {
      await tx.vehicleColour.deleteMany({ where: { colourId: id } });
      return tx.colour.delete({ where: { id } });
    });
  }
}
