export const AppPermission = {
  accountRead: 'account:read',
  accountWrite: 'account:write',
  sessionManage: 'session:manage',
  deviceManage: 'device:manage',
  sellerVerificationSubmit: 'seller_verification:submit',
  sellerVerificationReview: 'seller_verification:review',
  sellerVerifiedOperate: 'seller:verified_operate',
  sellerPremiumTools: 'seller:premium_tools',
  productManage: 'product:manage',
  contentManage: 'content:manage',

  /**
   * Publishing to the social feed as yourself.
   *
   * Deliberately not `contentManage`, which is the boutique's publishing
   * workspace — scheduling, versions, rollback, the campaign formats. A
   * shopper posting a photograph of a dress she bought is doing something
   * narrower, and giving her the seller permission to do it would hand her
   * flash offers and live streams as well.
   */
  contentAuthor: 'content:author',

  /**
   * Liking, saving, commenting, resharing.
   *
   * Split from authoring because they are revoked separately: a spam account
   * is silenced by taking this away, which stops it commenting everywhere
   * without deleting the woman's own page.
   */
  contentInteract: 'content:interact',

  contentTypeManage: 'content_type:manage',
  postManage: 'post:manage',
  storyManage: 'story:manage',
  orderManage: 'order:manage',
  orderRead: 'order:read',
  checkoutCreate: 'checkout:create',
  userManage: 'user:manage',
  supportRead: 'support:read',
  supportWrite: 'support:write',
  financeRead: 'finance:read',
  financeWrite: 'finance:write',
  contentModerate: 'content:moderate',
  analyticsRead: 'analytics:read',
  /**
   * Acting on the Trend Engine: acknowledging an insight, moving an unmet
   * demand signal along the sourcing workflow, re-running the pipeline.
   *
   * Separate from `analyticsRead` because reading the market and changing the
   * buying team's queue are different jobs. Everyone who can see the numbers
   * should not automatically be able to close a gap as "addressed".
   */
  trendsManage: 'trends:manage',
  /**
   * Editing and publishing the platform's policies — the two sets of terms,
   * privacy, returns, commissions, disputes, liability, content.
   *
   * Its own permission rather than `contentManage`, which every seller holds:
   * publishing a version of the terms of use changes the contract between Reem
   * and a hundred thousand accounts, and the person who moderates a caption is
   * not the person who should be able to do that. Held by SUPER_ADMIN and
   * OPERATIONS_ADMIN, and by nobody else by default.
   */
  policyManage: 'policy:manage',
  adminDashboard: 'admin:dashboard',
  authorizationManage: 'authorization:manage',
  guestSessionCreate: 'guest_session:create',
  guestSessionMigrate: 'guest_session:migrate',
  auditRead: 'audit:read',
  /**
   * Reading the authentication record of an account that is not yours.
   *
   * Separate from `auditRead` because it is a different question with a
   * different blast radius: audit answers "what did staff do", this answers
   * "how has this woman been signing in, and from where". Support needs the
   * second one to do its job and must not have it by accident.
   */
  securityForensicsRead: 'security_forensics:read',
  /** Reviewing a support-mediated account recovery. Two holders required. */
  accountRecoveryReview: 'account_recovery:review',
} as const;

export type AppPermissionKey =
  (typeof AppPermission)[keyof typeof AppPermission];
