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
import { CodTrustAdminService } from '../cod-trust/cod-trust.admin.service';
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

/**
 * Every staff role, and only staff roles.
 *
 * This list used to read `SUPER_ADMIN, ADMIN, SUPPORT`, which was harmless
 * while `@Authorize` replaced the contextual `@Roles` instead of narrowing it.
 * Once the guard started merging the two — correctly — that short list became
 * the ceiling for the whole console: a `FINANCE_ADMIN` holding `finance:read`,
 * an `OPERATIONS_ADMIN` holding `user:manage`, a `CONTENT_MODERATOR` holding
 * `content:moderate` were all bounced from `/admin/*` with a 403 despite the
 * role/permission map granting them exactly this work. The console routed them
 * to the admin experience and then refused every request it made.
 *
 * The narrowing that matters is per route: each handler names the permission it
 * needs, and `defaultPermissionsForRole` decides who holds it. This list is the
 * outer fence — it keeps shoppers and sellers out even if a permission is ever
 * granted too widely by mistake.
 */
@Roles(
  UserRole.SUPER_ADMIN,
  UserRole.ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.SUPPORT_ADMIN,
  UserRole.FINANCE_ADMIN,
  UserRole.CONTENT_MODERATOR,
  UserRole.SUPPORT,
)
@Controller('admin')
export class AdminController {
  constructor(
    private readonly admin: AdminService,
    private readonly codTrustAdmin: CodTrustAdminService,
  ) {}

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
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateProductAdminDto,
  ) {
    return this.admin.updateProduct(user.id, id, dto);
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
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateUserAdminDto,
  ) {
    return this.admin.updateUser(user.id, id, dto);
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

  /**
   * How the cash-on-delivery trust engine is performing.
   *
   * Under `finance:read` rather than `analytics:read`: the table it returns is
   * about money the platform chose not to put on the road, and the people who
   * answer for that number are the ones who answer for the rest of the cash.
   */
  @Authorize({
    action: 'read',
    resource: 'finance',
    permissions: [AppPermission.financeRead],
  })
  @Get('cod-trust')
  codTrust(@Query('days') days?: string) {
    const window = Number.parseInt(days ?? '30', 10);
    return this.codTrustAdmin.overview(
      Number.isFinite(window) ? Math.min(Math.max(window, 1), 365) : 30,
    );
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
  commissions(@Query() query: AdminListQueryDto) {
    return this.admin.commissions(query);
  }

  @Authorize({
    action: 'create',
    resource: 'finance',
    permissions: [AppPermission.financeWrite],
  })
  @Post('commissions/rules')
  @HttpCode(HttpStatus.CREATED)
  createCommissionRule(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateCommissionRuleDto,
  ) {
    return this.admin.createCommissionRule(user.id, dto);
  }

  @Authorize({
    action: 'update',
    resource: 'finance',
    permissions: [AppPermission.financeWrite],
  })
  @Patch('commissions/:id')
  updateCommissionLedger(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCommissionLedgerDto,
  ) {
    return this.admin.updateCommissionLedger(user.id, id, dto);
  }

  @Authorize({
    action: 'read',
    resource: 'support',
    permissions: [AppPermission.supportRead],
  })
  @Get('support')
  support(@Query() query: AdminListQueryDto) {
    return this.admin.support(query);
  }

  @Authorize({
    action: 'update',
    resource: 'support',
    permissions: [AppPermission.supportWrite],
  })
  @Patch('support/:id')
  updateSupport(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateSupportTicketDto,
  ) {
    return this.admin.updateSupportTicket(user.id, id, dto);
  }

  @Authorize({
    action: 'read',
    resource: 'content',
    permissions: [AppPermission.contentModerate],
  })
  @Get('moderation')
  moderation(@Query() query: AdminListQueryDto) {
    return this.admin.moderation(query);
  }

  @Authorize({
    action: 'update',
    resource: 'content',
    permissions: [AppPermission.contentModerate],
  })
  @Patch('moderation/:id')
  updateModeration(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateModerationCaseDto,
  ) {
    return this.admin.updateModeration(user.id, id, dto);
  }

  @Authorize({
    action: 'read',
    resource: 'support',
    permissions: [AppPermission.supportRead],
  })
  @Get('reports')
  reports(@Query() query: AdminListQueryDto) {
    return this.admin.reports(query);
  }

  @Authorize({
    action: 'update',
    resource: 'support',
    permissions: [AppPermission.supportWrite],
  })
  @Patch('reports/:id')
  updateReport(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateReportDto,
  ) {
    return this.admin.updateReport(user.id, id, dto);
  }

  @Authorize({
    action: 'read',
    resource: 'admin',
    permissions: [AppPermission.auditRead],
  })
  @Get('audit-logs')
  auditLogs(@Query() query: AdminListQueryDto) {
    return this.admin.auditLogs(query);
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
