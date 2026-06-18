export const AppPermission = {
  accountRead: 'account:read',
  accountWrite: 'account:write',
  sessionManage: 'session:manage',
  deviceManage: 'device:manage',
  sellerVerificationSubmit: 'seller_verification:submit',
  sellerVerificationReview: 'seller_verification:review',
  productManage: 'product:manage',
  postManage: 'post:manage',
  storyManage: 'story:manage',
  orderManage: 'order:manage',
  userManage: 'user:manage',
  auditRead: 'audit:read',
} as const;

export type AppPermissionKey =
  (typeof AppPermission)[keyof typeof AppPermission];
