import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CalculateQuotationDto, CreateQuotationDto } from './dto/quotation.dto';

@Injectable()
export class QuotationsService {
  constructor(private prisma: PrismaService) {}

  async calculate(dto: CalculateQuotationDto) {
    const vehicle = await this.prisma.vehicle.findUnique({
      where: { id: dto.vehicleId },
      include: { modelGroup: true },
    });
    if (!vehicle || vehicle.status !== 'Active') {
      throw new NotFoundException('Vehicle not found or inactive');
    }

    const branch = await this.prisma.branch.findUnique({
      where: { id: dto.branchId },
    });
    if (!branch || branch.status !== 'Active') {
      throw new NotFoundException('Branch not found or inactive');
    }

    const settings = await this.prisma.companySettings.findFirst();

    // Line items breakdown
    const exShowroom = Number(vehicle.exShowroomPrice);
    const onRoad = Number(vehicle.onRoadPrice);

    // Approximate RTO Road Tax & Insurance distribution from stored onRoad delta
    const diff = Math.max(0, onRoad - exShowroom);
    const roadTax = Math.round(diff * 0.65);
    const insurance = Math.round(diff * 0.35);

    const items: Array<{ label: string; amount: number }> = [
      { label: 'Ex-Showroom Price', amount: exShowroom },
      { label: 'RTO Registration & Road Tax', amount: roadTax },
      { label: 'Comprehensive Insurance', amount: insurance },
    ];

    // Hypothecation charge if Finance
    if (dto.purchaseMode?.toLowerCase() === 'finance' && settings) {
      if (settings.hypothecationCharge && Number(settings.hypothecationCharge) > 0) {
        items.push({
          label: 'Bank Hypothecation Loan Endorsement',
          amount: Number(settings.hypothecationCharge),
        });
      }
    }

    // Process accessories
    const accessoriesBreakdown: Array<{
      accessoryId: string;
      name: string;
      amount: number;
      isPriceEditable: boolean;
    }> = [];

    if (dto.accessories && dto.accessories.length > 0) {
      for (const item of dto.accessories) {
        const acc = await this.prisma.accessory.findUnique({
          where: { id: item.accessoryId },
        });
        if (!acc || acc.status !== 'Active') continue;

        let finalPrice = Number(acc.defaultPrice);
        if (acc.isPriceEditable && item.amount !== undefined) {
          finalPrice = Number(item.amount);
        }

        accessoriesBreakdown.push({
          accessoryId: acc.id,
          name: acc.name,
          amount: finalPrice,
          isPriceEditable: acc.isPriceEditable,
        });
      }
    }

    const itemsTotal = items.reduce((sum, it) => sum + it.amount, 0);
    const accessoriesTotal = accessoriesBreakdown.reduce((sum, it) => sum + it.amount, 0);
    const grandTotal = itemsTotal + accessoriesTotal;

    return {
      vehicle: {
        id: vehicle.id,
        code: vehicle.code,
        name: vehicle.name,
        category: vehicle.category,
        modelGroup: vehicle.modelGroup.name,
        quotePrefix: vehicle.modelGroup.quotePrefix,
      },
      branch: {
        id: branch.id,
        code: branch.code,
        name: branch.name,
      },
      colourName: dto.colourName,
      purchaseMode: dto.purchaseMode,
      exShowroom,
      roadTax,
      insurance,
      items,
      accessories: accessoriesBreakdown,
      itemsTotal,
      accessoriesTotal,
      grandTotal,
    };
  }

  async generateQuoteNumber(quotePrefix: string, branchCode: string, tx: any = this.prisma) {
    // Count existing quotations for this branch
    const count = await tx.quotation.count({
      where: {
        branch: { code: branchCode },
      },
    });
    const sequence = String(count + 1).padStart(5, '0');
    return `${quotePrefix}-${branchCode}-${sequence}`;
  }

  async create(dto: CreateQuotationDto, prismaTx?: any) {
    const runInTx = async (tx: any) => {
      const calc = await this.calculate(dto);
      const quoteNumber = await this.generateQuoteNumber(
        calc.vehicle.quotePrefix,
        calc.branch.code,
        tx,
      );

      const quotation = await tx.quotation.create({
        data: {
          quoteNumber,
          enquiryId: dto.enquiryId,
          branchId: dto.branchId,
          vehicleId: dto.vehicleId,
          colourName: dto.colourName,
          exShowroom: calc.exShowroom,
          roadTax: calc.roadTax,
          insurance: calc.insurance,
          grandTotal: calc.grandTotal,
          pdfR2Key: `quotes/${quoteNumber}.pdf`,
          items: {
            create: calc.items.map((it) => ({
              vehicleId: dto.vehicleId,
              label: it.label,
              amount: it.amount,
            })),
          },
          accessories: {
            create: calc.accessories.map((acc) => ({
              accessoryId: acc.accessoryId,
              amount: acc.amount,
            })),
          },
        },
        include: {
          items: true,
          accessories: {
            include: { accessory: true },
          },
          vehicle: {
            include: { modelGroup: true },
          },
          branch: true,
          enquiry: {
            include: { customer: true },
          },
        },
      });

      return quotation;
    };

    if (prismaTx) {
      return runInTx(prismaTx);
    } else {
      return this.prisma.$transaction(runInTx);
    }
  }

  async findAll(branchId?: string) {
    return this.prisma.quotation.findMany({
      where: branchId ? { branchId } : undefined,
      include: {
        vehicle: true,
        branch: true,
        enquiry: {
          include: { customer: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async findOne(id: string) {
    const quote = await this.prisma.quotation.findUnique({
      where: { id },
      include: {
        items: true,
        accessories: {
          include: { accessory: true },
        },
        vehicle: {
          include: { modelGroup: true },
        },
        branch: true,
        enquiry: {
          include: {
            customer: true,
            createdBy: { select: { id: true, name: true, mobile: true } },
          },
        },
      },
    });
    if (!quote) {
      throw new NotFoundException(`Quotation with ID ${id} not found`);
    }
    return quote;
  }
}

