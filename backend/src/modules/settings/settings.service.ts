import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  serializeAddress,
  serializeCoupon,
  serializeNotification,
  serializePaymentMethod,
} from '../../common/serializers';
import { AddressDto, UpdateAddressDto } from './dto/address.dto';
import { CreatePaymentMethodDto } from './dto/create-payment-method.dto';

@Injectable()
export class SettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async listAddresses(userId: string) {
    const addresses = await this.prisma.address.findMany({
      where: { userId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
    });
    return addresses.map(serializeAddress);
  }

  async createAddress(userId: string, dto: AddressDto) {
    const isFirst = (await this.prisma.address.count({ where: { userId } })) === 0;
    // Her first address is the default whether she said so or not — otherwise
    // checkout opens with nothing selected on the one order she has ever made.
    const isDefault = dto.is_default ?? isFirst;

    return this.prisma.$transaction(async (tx) => {
      if (isDefault) await this.clearDefault(tx, userId);

      const address = await tx.address.create({
        data: {
          userId,
          label: dto.label ?? 'المنزل',
          recipientName: dto.recipient_name,
          recipientPhone: dto.recipient_phone,
          governorate: dto.governorate,
          district: dto.district ?? null,
          city: dto.city,
          addressLine: dto.address_line,
          landmark: dto.landmark ?? null,
          isRural: dto.is_rural ?? false,
          deliveryInstructions: dto.delivery_instructions ?? null,
          isDefault,
        },
      });
      return serializeAddress(address);
    });
  }

  async updateAddress(userId: string, id: string, dto: UpdateAddressDto) {
    await this.requireAddress(userId, id);

    return this.prisma.$transaction(async (tx) => {
      if (dto.is_default) await this.clearDefault(tx, userId);

      const address = await tx.address.update({
        where: { id },
        data: {
          ...(dto.label !== undefined && { label: dto.label }),
          ...(dto.recipient_name !== undefined && {
            recipientName: dto.recipient_name,
          }),
          ...(dto.recipient_phone !== undefined && {
            recipientPhone: dto.recipient_phone,
          }),
          ...(dto.governorate !== undefined && { governorate: dto.governorate }),
          ...(dto.district !== undefined && { district: dto.district }),
          ...(dto.city !== undefined && { city: dto.city }),
          ...(dto.address_line !== undefined && {
            addressLine: dto.address_line,
          }),
          ...(dto.landmark !== undefined && { landmark: dto.landmark }),
          ...(dto.is_rural !== undefined && { isRural: dto.is_rural }),
          ...(dto.delivery_instructions !== undefined && {
            deliveryInstructions: dto.delivery_instructions,
          }),
          ...(dto.is_default !== undefined && { isDefault: dto.is_default }),
        },
      });
      return serializeAddress(address);
    });
  }

  async deleteAddress(userId: string, id: string) {
    const address = await this.requireAddress(userId, id);

    await this.prisma.$transaction(async (tx) => {
      await tx.address.delete({ where: { id } });

      // Deleting the default leaves the book with none, so the newest of what
      // remains takes over rather than leaving checkout with nothing selected.
      if (address.isDefault) {
        const next = await tx.address.findFirst({
          where: { userId },
          orderBy: { createdAt: 'desc' },
        });
        if (next) {
          await tx.address.update({
            where: { id: next.id },
            data: { isDefault: true },
          });
        }
      }
    });

    return { message: 'Address deleted' };
  }

  async setDefaultAddress(userId: string, id: string) {
    await this.requireAddress(userId, id);
    return this.prisma.$transaction(async (tx) => {
      await this.clearDefault(tx, userId);
      const address = await tx.address.update({
        where: { id },
        data: { isDefault: true },
      });
      return serializeAddress(address);
    });
  }

  private async clearDefault(tx: Prisma.TransactionClient, userId: string) {
    await tx.address.updateMany({
      where: { userId, isDefault: true },
      data: { isDefault: false },
    });
  }

  /** Ownership is checked here, not assumed from the token. */
  private async requireAddress(userId: string, id: string) {
    const address = await this.prisma.address.findFirst({
      where: { id, userId },
    });
    if (!address) throw new NotFoundException('Address not found');
    return address;
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
