import { Transform, Type } from 'class-transformer';
import {
  IsArray,
  IsEnum,
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import {
  ChatContextType,
  ChatReportReason,
  MessageKind,
} from '@prisma/client';

const upper = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.toUpperCase() : value;

export class MessageAttachmentDto {
  @Transform(upper)
  @IsEnum(MessageKind)
  kind!: MessageKind;

  @IsString()
  @MaxLength(2048)
  url!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  mime_type?: string;

  @IsOptional()
  @IsString()
  @MaxLength(180)
  file_name?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  size_bytes?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  width?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  height?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  duration_ms?: number;

  @IsOptional()
  metadata?: unknown;
}

export class SendMessageDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  content?: string;

  @IsOptional()
  @Transform(upper)
  @IsEnum(MessageKind)
  kind?: MessageKind;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  client_id?: string;

  @IsOptional()
  metadata?: unknown;

  /**
   * «اسألي عن هذه القطعة» — the piece this message is about. The server
   * resolves it into a product card on the message (title, photo, this
   * boutique's price), so the boutique sees what is being asked about — the
   * client's word for it is never what is shown.
   */
  @IsOptional()
  @IsUUID()
  product_id?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => MessageAttachmentDto)
  attachments?: MessageAttachmentDto[];
}

export class StartConversationDto {
  @IsOptional()
  @Transform(upper)
  @IsEnum(ChatContextType)
  type?: ChatContextType;

  @IsOptional()
  @IsUUID()
  participant_id?: string;

  @IsOptional()
  @IsUUID()
  seller_id?: string;

  @IsOptional()
  @IsUUID()
  product_id?: string;

  @IsOptional()
  @IsUUID()
  order_id?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  message?: string;
}

export class ChatListQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  q?: string;
}

export class MessageQueryDto {
  // The explicit `number` and `@Type` matter: a bare `page = 1` is recorded as
  // `Object`, so the query string `"50"` was never converted and every request
  // that sent `limit` — which the app always does — failed validation, and the
  // conversation opened on an error instead of its messages.
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit: number = 50;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  q?: string;

  /**
   * Messages strictly older than this instant — the `sent_at` of the oldest
   * message the client already holds. Takes precedence over `page`.
   */
  @IsOptional()
  @IsISO8601()
  before?: string;
}

export class DeleteMessageDto {
  /** `me` hides it from her side; `everyone` takes her own message back. */
  @IsIn(['me', 'everyone'])
  scope!: 'me' | 'everyone';
}

export class MarkReadDto {
  @IsOptional()
  @IsUUID()
  message_id?: string;
}

export class BlockUserDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class ReportUserDto {
  @IsUUID()
  reported_user_id!: string;

  @IsOptional()
  @IsUUID()
  message_id?: string;

  @Transform(upper)
  @IsEnum(ChatReportReason)
  reason!: ChatReportReason;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;
}
