# Seller Commerce Management Platform

## Scope

This architecture applies only to the Seller Application and seller-owned
backend surfaces. Customer experiences may consume public browse, feed,
checkout, reputation, and discovery APIs, but seller business operations stay
behind seller routes such as `/seller/products`, `/seller/content`, and
`/seller/commerce`.

## Current Assessment

The codebase already has strong foundations:

- Flutter seller features are separated into dashboard and product modules with
  data source, repository, use case, provider, and widget layers.
- Backend product and content management expose seller-specific controllers and
  enforce ownership server-side.
- Authorization, role permissions, audit/security primitives, analytics events,
  commissions, reputation, and universal commerce content are present.
- Public product/feed APIs are separate from seller management APIs.

The main architectural gaps are:

- The seller dashboard was mock-only, so the Seller Application had no
  production command-center read model.
- Seller commerce facts were scattered across products, orders, content,
  reputation, commissions, analytics, and favorites.
- Order totals are customer-order totals; seller dashboards must aggregate
  seller-owned order items to avoid leaking multi-seller order revenue.
- Inventory is still product-stock based. Enterprise reservations, warehouses,
  transfer ledgers, cycle counts, and forecasting need dedicated modules.
- Pricing is still product-price based. Scheduled, regional, tiered, campaign,
  coupon, and personalized pricing need a separate pricing engine.
- Workflow automation, media processing, AI provider abstraction, and
  enterprise reporting should be modules with stable ports, not widget logic.

## Implemented First Slice

This phase adds a Seller Commerce Overview application service:

- `GET /seller/commerce/overview`
- `SellerCommerceModule`
- `SellerCommerceService`
- `SellerDashboardRemoteDataSource`

The endpoint aggregates seller-owned facts into the existing dashboard entity
shape:

- store identity and seller reputation
- today, week, month, year, and lifetime seller revenue
- seller-scoped order counts
- chart datasets for daily, weekly, monthly, and yearly views
- top products by seller item revenue
- low-stock products
- conversion metrics
- rule-based AI insight placeholders
- pending operational tasks
- goals, reviews, campaigns, and module health

The mobile app now consumes this endpoint through the dashboard data source
boundary instead of letting widgets know about backend modules.

## Architectural Decisions

1. Keep seller operations under `/seller/*`.
   This preserves the boundary between Seller Application operations and public
   customer consumption.

2. Add a seller-commerce application service instead of overloading analytics.
   Analytics remains reusable business intelligence; seller commerce owns the
   command-center response contract and can compose products, orders, content,
   inventory, pricing, AI, and automation over time.

3. Aggregate revenue from `order_items` joined to seller-owned `products`.
   A customer order can contain products from multiple sellers, so seller
   revenue cannot safely use `orders.total`.

4. Keep Flutter domain entities stable.
   The new remote data source maps snake_case API responses into existing
   seller dashboard entities, preserving UI and state management contracts.

5. Treat current AI insights as rule-based recommendations.
   The response field is named for the product surface, but provider-backed AI
   generation should be added behind an AI commerce port before any model calls
   are introduced.

## Target Domain Modules

- Seller Command Center: aggregated KPIs, alerts, tasks, module health,
  executive reports, and seller workspace navigation.
- Catalog: products, variants, attributes, templates, media, quality scoring,
  version history, publishing, archive, and restore.
- Inventory: warehouses, locations, reservations, stock movements, transfers,
  adjustments, lots, serials, expiration, forecasts, and replenishment.
- Pricing: price books, rules, schedules, promotions, coupons, campaigns,
  customer groups, regions, currencies, margin policies, and optimization.
- Orders: seller order work queue, fulfillment, returns, refunds, exchanges,
  invoices, fraud signals, and order automation.
- Customers: seller customer profiles, segmentation, lifetime value, notes,
  loyalty, wallet, and behavioral insights.
- Content Commerce: content types, shoppable posts/stories/reels/live streams,
  product tags, campaigns, publishing lifecycle, analytics, and moderation.
- Analytics: event ledger, materialized read models, funnels, cohorts,
  retention, revenue, profit, inventory turnover, and report exports.
- AI Commerce: generation, optimization, recommendations, forecasts, fraud and
  anomaly detection, reports, and provenance tracking.
- Automation: triggers, conditions, filters, actions, schedules, idempotency,
  retries, workflow history, and plugin actions.
- Media: upload sessions, processing jobs, metadata, thumbnails, duplicate
  detection, streaming, CDN assets, and progressive loading.
- Security: RBAC, fine-grained permissions, audit logs, rate limits, abuse
  prevention, encryption boundaries, and seller verification policy.

## Phased Roadmap

1. Command center hardening
   - Add contract tests for `/seller/commerce/overview`.
   - Add cache headers and server-side read-model caching.
   - Add mobile stale-while-revalidate cache for dashboard reads.
   - Add observability for query latency and response freshness.

2. Materialized analytics read models
   - Move high-volume dashboard metrics from live joins to materialized seller
     fact tables updated by events.
   - Partition analytics and content event tables by time.
   - Add replayable event processors for revenue, conversion, and inventory
     facts.

3. Enterprise inventory
   - Introduce warehouses, locations, stock movement ledger, reservations, and
     replenishment policies.
   - Convert product stock mutations into inventory commands.
   - Add low-stock, overstock, dead-stock, and incoming-stock alert policies.

4. Pricing engine
   - Add price books, rule evaluation, schedules, campaign prices, coupon
     integration, and margin calculations.
   - Expose public resolved-price APIs to customer surfaces.
   - Keep seller price management private to the Seller Application.

5. Seller order operations
   - Add seller order queues scoped by order item ownership.
   - Support split fulfillment, shipment events, returns, refunds, exchanges,
     invoices, fraud signals, and automation hooks.

6. Automation and plugins
   - Add workflow definitions, trigger registry, action registry, execution
     logs, retry/idempotency keys, and plugin-owned actions.
   - Start with low-stock, order-completed, promotion-expired, and inactive
     product workflows.

7. AI commerce layer
   - Add provider interfaces for generation, scoring, recommendations,
     forecasting, and reports.
   - Store prompt version, model version, inputs, outputs, confidence, and human
     override metadata.

8. Seller workspace UX
   - Replace dashboard cards with module-aware drilldowns.
   - Add command palette, cross-module search, bulk operations, offline queues,
     and optimistic synchronization for seller workflows.

## Validation Expectations

Every phase should preserve these checks:

- Seller routes never expose another seller's data.
- Customer routes never gain seller management behavior.
- Revenue and order KPIs are item-seller scoped.
- Domain code does not depend on Flutter widgets, Dio, Prisma, or controller
  details.
- Mutations have authorization, auditability, and idempotency where retries are
  possible.
- Dashboard read paths either use bounded live queries or materialized read
  models with explicit freshness metadata.
