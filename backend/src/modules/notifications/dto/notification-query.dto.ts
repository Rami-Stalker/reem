import { IsIn, IsOptional } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export class NotificationQueryDto extends PaginationDto {
  @IsOptional()
  @IsIn(['true', 'false'])
  unread?: string;

  get unreadOnly(): boolean {
    return this.unread === 'true';
  }
}
