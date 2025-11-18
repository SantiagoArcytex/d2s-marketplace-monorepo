## 14. Capacity Planning

### 14.1 Load Testing Strategy

**Tools**: k6, Artillery, or Locust

**Test Scenarios**:

```javascript
// k6 load test script
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 500 }, // Ramp up to 500 users
    { duration: '5m', target: 500 }, // Stay at 500 users
    { duration: '2m', target: 1000 }, // Ramp up to 1000 users
    { duration: '5m', target: 1000 }, // Stay at 1000 users
    { duration: '2m', target: 0 }, // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200', 'p(99)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const res = http.get('https://api.platform.com/health');
  check(res, {
    'status is 200': (r) => r.status === 200,
  });
  sleep(1);
}
```

**Capacity Benchmarks**:

| Metric | Target | Measured |
|--------|--------|----------|
| **Concurrent Users** | 10,000 | TBD |
| **Requests per Second** | 5,000 RPS | TBD |
| **API Response Time (p95)** | < 200ms | TBD |
| **Database Query Time (p95)** | < 50ms | TBD |
| **Subdomain Lookup** | < 5ms (cached) | TBD |

### 14.2 Scaling Triggers

**Auto-Scaling Rules**:

- **ECS Tasks**: Scale up when CPU > 70% or memory > 80% for 5 minutes
- **Database Connections**: Alert when pool usage > 80%
- **API Gateway**: Throttle at 5,000 RPS per tenant
- **Redis**: Scale when operations > 100K/day

### 14.3 Capacity Planning Process

1. **Baseline Measurement**: Run load tests monthly
2. **Growth Projection**: 20% month-over-month growth
3. **Capacity Headroom**: Maintain 50% headroom
4. **Scaling Decisions**: Review quarterly

---

## 15. Disaster Recovery

### 15.1 RPO/RTO Objectives

- **RPO (Recovery Point Objective)**: 15 minutes (data loss tolerance)
- **RTO (Recovery Time Objective)**: 1 hour (downtime tolerance)

### 15.2 Backup Strategy

**Database Backups**:
- **Automated**: Daily backups via Supabase (7-day retention)
- **Manual**: Weekly full backups to S3 (30-day retention)
- **Point-in-Time Recovery**: Enabled (last 7 days)

**Redis Backups**:
- **RDB Persistence**: Enabled via Upstash
- **Snapshot Frequency**: Every 6 hours

**Application State**:
- **Terraform State**: Versioned in S3 with 90-day retention
- **Secrets**: Rotated every 90 days via AWS Secrets Manager

### 15.3 Disaster Recovery Procedures

**Database Failure**:
1. Promote read replica to primary (if available)
2. Update connection strings
3. Verify data integrity
4. **RTO**: 15 minutes

**ECS Service Failure**:
1. Rollback to previous task definition
2. Scale up healthy tasks
3. Verify health checks
4. **RTO**: 5 minutes

**Region Failure**:
1. Failover to secondary region (us-west-2)
2. Update Route53 DNS
3. Verify all services
4. **RTO**: 30 minutes

### 15.4 Backup Testing

**Monthly DR Drill**:
- Test database restore from backup
- Verify application functionality
- Document any issues
- Update runbooks

---

## 16. Security Scanning Pipeline

### 16.1 CI/CD Security Integration

**GitHub Actions / GitLab CI Pipeline**:

```yaml
# .github/workflows/security.yml
name: Security Scanning

on: [push, pull_request]

jobs:
  snyk-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Snyk to check for vulnerabilities
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

  owasp-zap:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ZAP Baseline Scan
        uses: zaproxy/action-baseline@v0.7.0
        with:
          target: 'https://staging.platform.com'

  codeql-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Initialize CodeQL
        uses: github/codeql-action/init@v2
        with:
          languages: javascript,typescript
      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v2
```

### 16.2 Security Scanning Tools

**Dependency Scanning**: Snyk
- Scans `package.json` and `package-lock.json`
- Checks for known vulnerabilities
- Blocks merge if high/critical vulnerabilities found

**Static Analysis**: GitHub CodeQL
- SAST (Static Application Security Testing)
- Detects common vulnerabilities (SQL injection, XSS, etc.)
- Integrated into PR checks

**Dynamic Analysis**: OWASP ZAP
- DAST (Dynamic Application Security Testing)
- Scans staging environment
- Weekly automated scans

**Container Scanning**: Trivy
- Scans Docker images for vulnerabilities
- Integrated into CI/CD pipeline

### 16.3 Security Findings Workflow

1. **Automated Scan**: Runs on every PR
2. **Findings Review**: Security team reviews high/critical issues
3. **Remediation**: Developer fixes issues
4. **Re-scan**: Verify fixes
5. **Approval**: Security team approves merge

### 16.4 Security.txt

```text
# /.well-known/security.txt
Contact: security@platform.com
Expires: 2025-12-31T23:59:59.000Z
Preferred-Languages: en
Canonical: https://platform.com/.well-known/security.txt
```

---

## 17. Payment Reconciliation

### 17.1 Automated Reconciliation

**Daily Reconciliation Job**:

```typescript
// src/modules/payments/services/reconciliation.service.ts
@Injectable()
export class ReconciliationService {
  async reconcileDaily() {
    // 1. Get all subscriptions from database
    const subscriptions = await db.query.subscriptions.findMany({
      where: eq(subscriptions.status, 'active'),
    });

    // 2. Fetch current status from GoHighLevel
    for (const sub of subscriptions) {
      const ghlStatus = await this.ghlProvider.getSubscriptionStatus(
        sub.provider_subscription_id
      );

      // 3. Compare and flag discrepancies
      if (ghlStatus.status !== sub.status) {
        await this.flagDiscrepancy(sub, ghlStatus);
      }
    }
  }

  private async flagDiscrepancy(sub: Subscription, ghlStatus: any) {
    await db.insert(reconciliationDiscrepancies).values({
      subscription_id: sub.id,
      our_status: sub.status,
      provider_status: ghlStatus.status,
      flagged_at: new Date(),
      resolved: false,
    });

    // Notify admin
    await this.notificationService.send({
      user_id: ADMIN_USER_ID,
      type: 'reconciliation_discrepancy',
      title: 'Payment Reconciliation Discrepancy',
      body: `Subscription ${sub.id} status mismatch`,
    });
  }
}
```

### 17.2 Manual Reconciliation UI

**Admin Dashboard Features**:
- View all failed webhooks (DLQ)
- View reconciliation discrepancies
- Manually process webhooks
- Update subscription status
- Export reconciliation reports

### 17.3 Reconciliation Reports

**Monthly Report**:
- Total webhooks processed
- Failed webhooks count
- Discrepancies found
- Resolution rate
- Average processing time

---

## 18. Cache Strategy

### 18.1 Multi-Layer Caching Architecture

```
┌─────────────────────────────────────────┐
│  Browser Cache (1 year TTL)             │
│  - Static assets                         │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  CloudFront CDN (10min API, 1yr static) │
│  - Global edge locations                 │
│  - API response caching                  │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Vercel Edge Config (< 5ms)              │
│  - Subdomain routing table               │
│  - Updated via webhook                   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Upstash Redis (5min TTL)               │
│  - Hot data (tenant info, app configs)  │
│  - Rate limiting counters               │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Database Query Cache                    │
│  - Prepared statements                  │
│  - Materialized views                    │
└─────────────────────────────────────────┘
```

### 18.2 Cache Invalidation Strategy

**Subdomain Routing**:
- Invalidate Edge Config when app created/updated/deleted
- Webhook triggers Edge Config update

**Tenant Data**:
- Invalidate Redis cache on tenant update
- TTL-based expiration (5 minutes)

**Application Data**:
- Cache-aside pattern
- Invalidate on write operations

### 18.3 Cache Warming

**On Application Start**:
```typescript
// Warm up frequently accessed data
async function warmCache() {
  const activeTenants = await db.query.tenants.findMany({
    where: eq(tenants.status, 'active'),
    limit: 100,
  });

  for (const tenant of activeTenants) {
    await redis.setex(`tenant:${tenant.id}`, 300, JSON.stringify(tenant));
  }
}
```

---

## 19. Error Handling Strategy

### 19.1 Global Error Handler

```typescript
// src/common/filters/http-exception.filter.ts
import { ExceptionFilter, Catch, ArgumentsHost, HttpException } from '@nestjs/common';
import { Request, Response } from 'express';
import * as Sentry from '@sentry/node';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = 500;
    let message = 'Internal server error';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      message = exception.message;
    }

    // Log to Sentry (only for 5xx errors)
    if (status >= 500) {
      Sentry.captureException(exception, {
        tags: {
          path: request.url,
          method: request.method,
          tenant_id: request.headers['x-tenant-id'],
        },
      });
    }

    response.status(status).json({
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      message,
    });
  }
}
```

### 19.2 Error Boundaries (Frontend)

```tsx
// components/ErrorBoundary.tsx
import React from 'react';

class ErrorBoundary extends React.Component {
  state = { hasError: false };

  static getDerivedStateFromError(error: Error) {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    // Log to Sentry
    Sentry.captureException(error, { contexts: { react: errorInfo } });
  }

  render() {
    if (this.state.hasError) {
      return <ErrorFallback />;
    }
    return this.props.children;
  }
}
```

### 19.3 Retry Logic

```typescript
// src/common/utils/retry.util.ts
export async function retry<T>(
  fn: () => Promise<T>,
  maxAttempts: number = 3,
  delay: number = 1000
): Promise<T> {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === maxAttempts) throw error;
      await sleep(delay * attempt); // Exponential backoff
    }
  }
  throw new Error('Max retries exceeded');
}
```

---

## 20. API Rate Limiting

### 20.1 Global Rate Limiting (API Gateway)

**AWS API Gateway Throttling**:
- **Burst Limit**: 5,000 requests
- **Steady State**: 10,000 requests/second
- **Per-Key**: 1,000 requests/second per API key

### 20.2 Per-Tenant Rate Limiting

```typescript
// src/common/guards/rate-limit.guard.ts
import { Injectable, CanActivate, ExecutionContext, TooManyRequestsException } from '@nestjs/common';
import { Redis } from '@upstash/redis';

@Injectable()
export class RateLimitGuard implements CanActivate {
  private redis = new Redis({
    url: process.env.UPSTASH_REDIS_REST_URL,
    token: process.env.UPSTASH_REDIS_REST_TOKEN,
  });

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const tenantId = request.tenantId;
    const key = `rate_limit:${tenantId}`;

    // Fixed window rate limiting
    const current = await this.redis.incr(key);
    if (current === 1) {
      await this.redis.expire(key, 60); // 1 minute window
    }

    const limit = this.getTierLimit(request.tenant.tier);
    if (current > limit) {
      throw new TooManyRequestsException(
        `Rate limit exceeded. Limit: ${limit} requests/min`
      );
    }

    return true;
  }

  private getTierLimit(tier: string): number {
    const limits = {
      free: 100,
      pro: 1000,
      enterprise: 10000,
    };
    return limits[tier] || 100;
  }
}
```

### 20.3 Rate Limit Headers

```typescript
// Add rate limit headers to responses
response.setHeader('X-RateLimit-Limit', limit);
response.setHeader('X-RateLimit-Remaining', limit - current);
response.setHeader('X-RateLimit-Reset', Date.now() + 60000);
```

---

## 21. Risk Assessment & Mitigation

### 21.1 Risk Matrix

| Risk | Likelihood | Impact | Mitigation | Owner |
|------|-----------|--------|------------|-------|
| **GoHighLevel API Changes** | Medium | High | Abstract behind `IPaymentProvider`; monitor API changelog | Backend Lead |
| **Supabase Outage** | Low | Critical | Daily backups; read replica; 1-hour RTO plan | DevOps |
| **Redis Data Loss** | Low | Medium | Upstash with RDB persistence; PostgreSQL fallback | Backend Lead |
| **Subdomain Takeover** | Low | High | Automated DNS validation; wildcard SSL monitoring | Security Engineer |
| **Database Connection Exhaustion** | Medium | High | Connection pooling; monitoring; auto-scaling | DevOps |
| **Cold Start Latency** | Medium | Medium | Edge Config caching; warm-up strategies | Backend Lead |
| **Quota Enforcement Bypass** | Low | High | RLS policies + application checks; audit logs | Security Engineer |
| **Payment Webhook Failures** | Medium | High | SQS retry + DLQ; reconciliation UI | Backend Lead |
| **Schema Migration Failure** | Low | Critical | Blue-green deployment; shadow DB testing | DevOps |
| **Cost Overrun** | Medium | Medium | Budget alerts at 80%; usage monitoring | CTO |

### 21.2 High-Priority Mitigations

1. **Payment webhook retry mechanism** ✅ (SQS + DLQ)
2. **Database connection pooling** ✅ (Session/transaction modes)
3. **Subdomain DNS validation** ✅ (Automated checks)
4. **Budget monitoring alerts** ✅ (CloudWatch alarms)

---

## 22. Runbooks

### 22.1 Common Scenarios

#### **Scenario: Payment Webhook Processing Failure**

1. **Identify**: Check DLQ for failed messages
2. **Investigate**: Review error logs in CloudWatch
3. **Resolve**: 
   - If transient: Retry manually via reconciliation UI
   - If permanent: Update webhook mapping, reprocess
4. **Verify**: Check subscription status matches GoHighLevel

#### **Scenario: Database Connection Pool Exhausted**

1. **Identify**: CloudWatch alarm triggers
2. **Investigate**: Check for connection leaks
3. **Resolve**:
   - Scale up ECS tasks (temporary)
   - Fix connection leaks (permanent)
4. **Verify**: Monitor connection pool metrics

#### **Scenario: High API Error Rate**

1. **Identify**: Datadog alert triggers (> 1% error rate)
2. **Investigate**: Check Sentry for error patterns
3. **Resolve**: 
   - Rollback recent deployment if needed
   - Fix root cause
4. **Verify**: Monitor error rate returns to normal

### 22.2 On-Call Procedures

**Escalation Path**:
1. **Level 1**: On-call engineer (PagerDuty)
2. **Level 2**: Team lead (if unresolved in 15 min)
3. **Level 3**: CTO (if critical, unresolved in 30 min)

**Communication**:
- Post updates in #incidents Slack channel
- Update status page if customer-facing
- Post-mortem within 48 hours

---

## 23. Developer Documentation

### 23.1 API Documentation

**tRPC Auto-Generated Docs**:
- Available at `/trpc/docs` (development)
- OpenAPI spec export for external developers

### 23.2 Getting Started Guide

**For New Developers**:

1. **Prerequisites**:
   - Node.js 20+
   - Docker & Docker Compose
   - AWS CLI configured

2. **Setup**:
   ```bash
   git clone https://github.com/org/saas-marketplace.git
   cd saas-marketplace
   docker-compose up -d
   npm install
   npm run dev
   ```

3. **Running Tests**:
   ```bash
   npm run test
   npm run test:e2e
   ```

### 23.3 Architecture Decision Records (ADRs)

**Template**:
```markdown
# ADR-001: Use Edge Config for Subdomain Routing

## Status
Accepted

## Context
Subdomain routing requires fast lookups (< 5ms) for good UX.

## Decision
Use Vercel Edge Config for cached subdomain lookups.

## Consequences
- Fast lookups (< 5ms)
- Requires webhook to update on app changes
- Additional cost: $0 (included in Vercel Pro)
```

---

## Appendix A: Code Examples

### A.1 Complete tRPC Router

```typescript
// src/trpc/routers/index.ts
import { router } from '../trpc';
import { authRouter } from './auth.router';
import { appsRouter } from './apps.router';
import { marketplaceRouter } from './marketplace.router';

export const appRouter = router({
  auth: authRouter,
  apps: appsRouter,
  marketplace: marketplaceRouter,
});

export type AppRouter = typeof appRouter;
```

### A.2 Payment Provider Factory

```typescript
// src/modules/payments/factories/payment-provider.factory.ts
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { IPaymentProvider } from '../interfaces/payment-provider.interface';
import { GoHighLevelProvider } from '../providers/gohighlevel.provider';
import { StripeProvider } from '../providers/stripe.provider';

@Injectable()
export class PaymentProviderFactory {
  constructor(
    private config: ConfigService,
    private ghl: GoHighLevelProvider,
    private stripe: StripeProvider,
  ) {}

  getProvider(tenantId?: string): IPaymentProvider {
    if (tenantId) {
      const tenant = await db.query.tenants.findFirst({
        where: eq(tenants.id, tenantId),
      });
      if (tenant?.payment_provider === 'stripe') {
        return this.stripe;
      }
    }
    return this.ghl;
  }
}
```

---

## Appendix B: Phase 2 Roadmap

See original document for Phase 2 details (Community Marketplace, Stripe Integration).

**Key Additions for Phase 2**:
- OAuth bridge with PKCE ✅
- Security scanning pipeline ✅
- Enhanced payment reconciliation ✅

---

## Appendix C: Terraform Infrastructure

See separate Terraform documentation for complete infrastructure as code.

**Key Components**:
- VPC with public/private subnets
- ECS Fargate cluster with auto-scaling
- ALB with WAF
- CloudFront distribution
- API Gateway
- SQS queues with DLQ
- Secrets Manager
- CloudWatch alarms

---

## Conclusion

This **System/Software Design Document v2.0** provides a **production-ready, enterprise-grade architecture** for the SaaS marketplace platform. All critical concerns have been addressed:

✅ **Subdomain Routing**: Edge Config caching (< 5ms lookups)  
✅ **Payment Integration**: SQS + DLQ + reconciliation  
✅ **Database Pooling**: Session/transaction modes with monitoring  
✅ **Redis Architecture**: WebSocket/SSE with connection pooling  
✅ **Security**: PKCE, token revocation, scanning pipeline  
✅ **Observability**: Complete with X-Ray, Sentry, query monitoring  
✅ **Cost Analysis**: Refined with 30% buffer  
✅ **Missing Elements**: All added (rate limiting, CORS, error handling, backups)  

**Ready for immediate implementation.**

