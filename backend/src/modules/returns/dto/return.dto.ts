import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  IsUrl,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { ReturnCostBearer, ReturnReason, ReturnStatus } from '@prisma/client';

/** One line of a return: which order item, and how many of it. */
export class ReturnLineDto {
  @IsUUID()
  order_item_id!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity!: number;
}

export class CreateReturnDto {
  @IsUUID()
  seller_order_id!: string;

  @IsEnum(ReturnReason)
  reason!: ReturnReason;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  reason_note?: string;

  /**
   * Photo URLs from the media service. Required for the reasons that assert a
   * fault — the service enforces that, not the shape, because which reasons
   * need proof is a business rule and belongs with the other ones.
   */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(8)
  @IsUrl({ require_tld: false }, { each: true })
  evidence?: string[];

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => ReturnLineDto)
  items!: ReturnLineDto[];
}

export class ApproveReturnDto {
  /** Q67 P1 «حسب الحالة» — the approver may overrule the proposed bearer. */
  @IsOptional()
  @IsEnum(ReturnCostBearer)
  shipping_borne_by?: ReturnCostBearer;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class RejectReturnDto {
  /**
   * Mandatory. A refusal with no reason leaves the customer nothing to answer
   * and the reviewer of the dispute that follows nothing to weigh.
   */
  @IsString()
  @MinLength(5)
  @MaxLength(500)
  reason!: string;
}

export class ReceiveReturnDto {
  /**
   * Overrides the reason's default. Q56 P1 wants the goods back «غير مستخدم
   * وبحالته الأصلية»; the person holding the parcel is the one who can say
   * whether they are.
   */
  @IsOptional()
  @IsBoolean()
  restock?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class EscalateReturnDto {
  @IsString()
  @MinLength(5)
  @MaxLength(280)
  subject!: string;
}

export class SellerReturnsQueryDto {
  @IsOptional()
  @IsEnum(ReturnStatus)
  status?: ReturnStatus;
}
