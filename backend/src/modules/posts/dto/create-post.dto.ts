import { IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class CreatePostDto {
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  caption!: string;

  @IsUUID()
  product_id!: string;
}
