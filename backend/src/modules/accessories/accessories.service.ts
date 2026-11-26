import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateAccessoryDto, UpdateAccessoryDto } from './dto/accessory.dto';

@Injectable()
export class AccessoriesService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.accessory.findMany({
      orderBy: [{ isStandard: 'desc' }, { sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  async findOne(id: string) {
    const accessory = await this.prisma.accessory.findUnique({
      where: { id },
    });
    if (!accessory) {
      throw new NotFoundException(`Accessory with ID ${id} not found`);
    }
    return accessory;
  }

  async create(dto: CreateAccessoryDto) {
    return this.prisma.accessory.create({
      data: dto,
    });
  }

  async update(id: string, dto: UpdateAccessoryDto) {
    await this.findOne(id);
    return this.prisma.accessory.update({
      where: { id },
      data: dto,
    });
  }

  async updateImage(id: string, imageUrl: string | null) {
    await this.findOne(id);
    return this.prisma.accessory.update({
      where: { id },
      data: { imageUrl },
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    const usedCount = await this.prisma.quotationAccessory.count({
      where: { accessoryId: id },
    });
    if (usedCount > 0) {
      throw new BadRequestException(
        'Cannot delete accessory because it is used in existing quotations. Mark it Inactive instead.',
      );
    }
    return this.prisma.accessory.delete({
      where: { id },
    });
  }
}
