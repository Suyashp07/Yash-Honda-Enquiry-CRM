import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateAccessoryDto, UpdateAccessoryDto } from './dto/accessory.dto';

@Injectable()
export class AccessoriesService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.accessory.findMany({
      orderBy: { name: 'asc' },
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

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.accessory.update({
      where: { id },
      data: { status: 'Inactive' },
    });
  }
}
