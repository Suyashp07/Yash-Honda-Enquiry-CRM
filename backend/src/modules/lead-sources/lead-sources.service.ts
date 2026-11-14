import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateLeadSourceDto, UpdateLeadSourceDto } from './dto/lead-source.dto';

@Injectable()
export class LeadSourcesService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.leadSource.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async findOne(id: string) {
    const ls = await this.prisma.leadSource.findUnique({
      where: { id },
    });
    if (!ls) {
      throw new NotFoundException(`Lead source with ID ${id} not found`);
    }
    return ls;
  }

  async create(dto: CreateLeadSourceDto) {
    return this.prisma.leadSource.create({
      data: dto,
    });
  }

  async update(id: string, dto: UpdateLeadSourceDto) {
    await this.findOne(id);
    return this.prisma.leadSource.update({
      where: { id },
      data: dto,
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.leadSource.update({
      where: { id },
      data: { status: 'Inactive' },
    });
  }
}

