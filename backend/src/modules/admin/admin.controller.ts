import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import { ReviewSellerVerificationDto } from '../auth/dto/account.dto';
import { AdminService } from './admin.service';
import {
  AdminListQueryDto,
  CreateCommissionRuleDto,
  UpdateCommissionLedgerDto,
  UpdateModerationCaseDto,
  UpdateProductAdminDto,
  UpdateReportDto,
  UpdateSupportTicketDto,
  UpdateUserAdminDto,
  UpsertSystemSettingDto,
} from './dto/admin.dto';

@Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Authorize({
    action: 'read',
    resource: 'admin',
    permissions: [AppPermission.adminDashboard],
  })
  @Get('stats')
  stats() {
    return this.admin.stats();
  }

  @Authorize({
    action: 'read',
    resource: 'order',
    permissions: [AppPermission.orderRead],
  })
  @Get('orders')
  orders(@Query() query: AdminListQueryDto) {
    return this.admin.orders(query);
  }

  @Authorize({
    action: 'read',
    resource: 'content',
    permissions: [AppPermission.productManage],
  })
  @Get('products')
  products(@Query() query: AdminListQueryDto) {
    return this.admin.products(query);
  }

  @Authorize({
    action: 'update',
    resource: 'content',
    permissions: [AppPermission.productManage],
  })
  @Patch('products/:id')
  updateProduct(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateProductAdminDto,
  ) {
    return this.admin.updateProduct(id, dto);
  }

  @Authorize({
    action: 'read',
    resource: 'admin',
    permissions: [AppPermission.userManage],
  })
  @Get('users')
  users(@Query() query: AdminListQueryDto) {
    return this.admin.users(query);
  }

  @Authorize({
    action: 'update',
    resource: 'admin',
    permissions: [AppPermission.userManage],
  })
  @Patch('users/:id')
  updateUser(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateUserAdminDto,
  ) {
    return this.admin.updateUser(id, dto);
  }

  @Authorize({
    action: 'read',
    resource: 'seller',
    permissions: [AppPermission.sellerVerificationReview],
  })
  @Get('sellers')
  sellers(@Query() query: AdminListQueryDto) {
    return this.admin.sellers(query);
  }

  @Authorize({
    action: 'read',
    resource: 'seller',
    permissions: [AppPermission.sellerVerificationReview],
  })
  @Get('seller-applications')
  sellerApplications(@Query() query: AdminListQueryDto) {
    return this.admin.sellerApplications(query);
  }

  @Authorize({
    action: 'read',
    resource: 'seller',
    permissions: [AppPermission.sellerVerificationReview],
  })
  @Get('seller-applications/:id')
  sellerApplication(@Param('id', ParseUUIDPipe) id: string) {
    return this.admin.sellerApplication(id);
  }

  @Authorize({
    action: 'review',
    resource: 'seller',
    permissions: [AppPermission.sellerVerificationReview],
  })
  @Patch('seller-applications/:id/review')
  reviewSellerApplication(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReviewSellerVerificationDto,
  ) {
    return this.admin.reviewSellerApplication(user.id, id, dto);
  }

  @Authorize({
    action: 'read',
    resource: 'analytics',
    permissions: [AppPermission.analyticsRead],
  })
  @Get('analytics')
  analytics() {
    return this.admin.analytics();
  }

  @Authorize({
    action: 'read',
    resource: 'finance',
    permissions: [AppPermission.financeRead],
  })
  @Get('financials')
  financials() {
    return this.admin.financials();
  }

  @Authorize({
    action: 'read',
    resource: 'finance',
    permissions: [AppPermission.financeRead],
  })
  @Get('commissions')
  commissions() {
    return this.admin.commissions();
  }

  @Authorize({
    action: 'create',
    resource: 'finance',
    permissions: [AppPermission.financeWrite],
  })
  @Post('commissions/rules')
  @HttpCode(HttpStatus.CREATED)
  createCommissionRule(@Body() dto: CreateCommissionRuleDto) {
    return this.admin.createCommissionRule(dto);
  }

  @Authorize({
    action: 'update',
    resource: 'finance',
    permissions: [AppPermission.financeWrite],
  })
  @Patch('commissions/:id')
  updateCommissionLedger(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCommissionLedgerDto,
  ) {
    return this.admin.updateCommissionLedger(id, dto);
  }

  @Authorize({
    action: 'read',
    resource: 'support',
    permissions: [AppPermission.supportRead],
  })
  @Get('support')
  support() {
    return this.admin.support();
  }

  @Authorize({
    action: 'update',
    resource: 'support',
    permissions: [AppPermission.supportWrite],
  })
  @Patch('support/:id')
  updateSupport(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateSupportTicketDto,
  ) {
    return this.admin.updateSupportTicket(id, dto);
  }

  @Authorize({
    action: 'read',
    resource: 'content',
    permissions: [AppPermission.contentModerate],
  })
  @Get('moderation')
  moderation() {
    return this.admin.moderation();
  }

  @Authorize({
    action: 'update',
    resource: 'content',
    permissions: [AppPermission.contentModerate],
  })
  @Patch('moderation/:id')
  updateModeration(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateModerationCaseDto,
  ) {
    return this.admin.updateModeration(id, dto);
  }

  @Authorize({
    action: 'read',
    resource: 'support',
    permissions: [AppPermission.supportRead],
  })
  @Get('reports')
  reports() {
    return this.admin.reports();
  }

  @Authorize({
    action: 'update',
    resource: 'support',
    permissions: [AppPermission.supportWrite],
  })
  @Patch('reports/:id')
  updateReport(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateReportDto,
  ) {
    return this.admin.updateReport(id, dto);
  }

  @Authorize({
    action: 'read',
    resource: 'admin',
    permissions: [AppPermission.auditRead],
  })
  @Get('audit-logs')
  auditLogs() {
    return this.admin.auditLogs();
  }

  @Authorize({
    action: 'read',
    resource: 'admin',
    permissions: [AppPermission.authorizationManage],
  })
  @Get('system-settings')
  systemSettings() {
    return this.admin.systemSettings();
  }

  @Authorize({
    action: 'write',
    resource: 'admin',
    permissions: [AppPermission.authorizationManage],
  })
  @Post('system-settings')
  @HttpCode(HttpStatus.OK)
  upsertSystemSetting(
    @CurrentUser() user: AuthUser,
    @Body() dto: UpsertSystemSettingDto,
  ) {
    return this.admin.upsertSystemSetting(user.id, dto);
  }
}
