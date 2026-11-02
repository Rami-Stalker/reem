import { Body, Controller, Get, Put } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

import { Authorize } from '../../common/decorators/authorize.decorator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { AppPermission } from '../../common/permissions';
import { PrismaService } from '../../prisma/prisma.service';

const tidy = ({ value }: { value: unknown }) =>
  Array.isArray(value)
    ? [...new Set(value.map((entry) => String(entry).trim()).filter(Boolean))]
    : value;

export class SellerDeliverySettingsDto {
  @IsBoolean()
  self_delivery_enabled!: boolean;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(14)
  @IsString({ each: true })
  @MaxLength(60, { each: true })
  @Transform(tidy)
  self_delivery_governorates?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsString({ each: true })
  @MaxLength(60, { each: true })
  @Transform(tidy)
  self_delivery_cities?: string[];
}

/**
 * Q57 — how her boutique delivers.
 *
 * Off: the platform's contracted carriers take every parcel. On: she carries
 * the parcels addressed inside her area herself, and the carriers take the
 * rest. Decided per parcel at checkout, so changing it never moves an order
 * that is already placed.
 */
@Authorize({
  action: 'manage',
  resource: 'order',
  roles: [UserRole.SELLER],
  permissions: [AppPermission.orderRead],
  requireSellerVerified: true,
})
@Controller('seller/delivery-settings')
export class SellerDeliverySettingsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async get(@CurrentUser() user: AuthUser) {
    const row = await this.prisma.sellerDeliverySettings.findUnique({
      where: { sellerId: user.id },
    });
    return this.serialize(row);
  }

  @Put()
  async put(@CurrentUser() user: AuthUser, @Body() dto: SellerDeliverySettingsDto) {
    const data = {
      selfDeliveryEnabled: dto.self_delivery_enabled,
      selfDeliveryGovernorates: dto.self_delivery_governorates ?? [],
      selfDeliveryCities: dto.self_delivery_cities ?? [],
    };
    const row = await this.prisma.sellerDeliverySettings.upsert({
      where: { sellerId: user.id },
      create: { sellerId: user.id, ...data },
      update: data,
    });
    return this.serialize(row);
  }

  private serialize(
    row: {
      selfDeliveryEnabled: boolean;
      selfDeliveryGovernorates: string[];
      selfDeliveryCities: string[];
    } | null,
  ) {
    const enabled = row?.selfDeliveryEnabled ?? false;
    const governorates = row?.selfDeliveryGovernorates ?? [];
    const cities = row?.selfDeliveryCities ?? [];
    return {
      self_delivery_enabled: enabled,
      self_delivery_governorates: governorates,
      self_delivery_cities: cities,
      // One sentence the screen can show as-is.
      summary: !enabled
        ? 'كل الطلبات تُسلَّم لشركة التوصيل المتعاقدة'
        : governorates.length === 0 && cities.length === 0
          ? 'توصلين كل الطلبات بنفسك'
          : `توصلين بنفسك داخل ${[...cities, ...governorates].join('، ')} — وشركة التوصيل لباقي المناطق`,
    };
  }
}
