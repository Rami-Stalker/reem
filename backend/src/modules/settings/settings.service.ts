import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  serializeAddress,
  serializeCoupon,
  serializeNotification,
  serializePaymentMethod,
} from '../../common/serializers';
import { CreateAddressDto } from './dto/create-address.dto';
import { CreatePaymentMethodDto } from './dto/create-payment-method.dto';

@Injectable()
export class SettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async listAddresses(userId: string) {
    const addresses = await this.prisma.address.findMany({
      where: { userId },
      orderBy: { isDefault: 'desc' },
    });
    return addresses.map(serializeAddress);
  }

  async createAddress(userId: string, dto: CreateAddressDto) {
    if (dto.is_default) {
      await this.prisma.address.updateMany({
        where: { userId },
        data: { isDefault: false },
      });
    }
    const address = await this.prisma.address.create({
      data: {
        userId,
        label: dto.label,
        street: dto.street,
        city: dto.city,
        country: dto.country,
        postalCode: dto.postal_code ?? null,
        isDefault: dto.is_default ?? false,
      },
    });
    return serializeAddress(address);
  }

  async listCoupons() {
    const coupons = await this.prisma.coupon.findMany({
      where: { isActive: true, expiresAt: { gt: new Date() } },
    });
    return coupons.map(serializeCoupon);
  }

  async rewards(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    return {
      points: user?.points ?? 0,
      lifetime_points: user?.lifetimePoints ?? 0,
      tier: user?.tier ?? 'Bronze',
    };
  }

  async listNotifications(userId: string) {
    const notifications = await this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    return notifications.map(serializeNotification);
  }

  async listPaymentMethods(userId: string) {
    const methods = await this.prisma.paymentMethod.findMany({ where: { userId } });
    return methods.map(serializePaymentMethod);
  }

  async createPaymentMethod(userId: string, dto: CreatePaymentMethodDto) {
    if (dto.is_default) {
      await this.prisma.paymentMethod.updateMany({
        where: { userId },
        data: { isDefault: false },
      });
    }
    const pm = await this.prisma.paymentMethod.create({
      data: {
        userId,
        brand: dto.brand,
        last4: dto.last4,
        expMonth: dto.exp_month,
        expYear: dto.exp_year,
        isDefault: dto.is_default ?? false,
      },
    });
    return serializePaymentMethod(pm);
  }
}
