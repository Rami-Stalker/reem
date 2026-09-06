import { Module } from '@nestjs/common';
import { CodTrustModule } from '../cod-trust/cod-trust.module';
import { AuthModule } from '../auth/auth.module';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [AuthModule, CodTrustModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
