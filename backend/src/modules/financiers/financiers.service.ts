import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateFinancierDto, UpdateFinancierDto } from './dto/financier.dto';

@Injectable()
export class FinanciersService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.financier.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async findOne(id: string) {
    const financier = await this.prisma.financier.findUnique({
      where: { id },
    });
    if (!financier) {
      throw new NotFoundException(`Financier with ID ${id} not found`);
    }
    return financier;
  }

  async create(dto: CreateFinancierDto) {
    return this.prisma.financier.create({
      data: dto,
    });
  }

  async update(id: string, dto: UpdateFinancierDto) {
    await this.findOne(id);
    return this.prisma.financier.update({
      where: { id },
      data: dto,
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.$transaction(async (tx) => {
      await tx.enquiry.updateMany({
        where: { financierId: id },
        data: { financierId: null },
      });
      return tx.financier.delete({
        where: { id },
      });
    });
  }
}

