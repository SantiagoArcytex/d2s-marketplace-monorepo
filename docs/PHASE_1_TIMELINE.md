# Phase 1: Foundations - Quick Reference Timeline (1 Week)

## 1-Week Sprint Overview

```
Day 1: AWS & Terraform Backend
├── Morning: AWS Account, IAM, Domain, GitHub
└── Afternoon: Terraform Backend (S3 + DynamoDB)

Day 2: VPC & ECR
├── Morning: VPC Module & Deployment
└── Afternoon: Security Groups & ECR

Day 3: ECS & ALB
├── Morning: ECS Module & Cluster
└── Afternoon: ALB & SSL Certificate

Day 4: Supabase & Database
├── Morning: Supabase Project Setup
└── Afternoon: Schema & RLS Policies

Day 5: Vercel & Edge Config
├── Morning: Vercel Project & Deployment
└── Afternoon: Edge Config & Subdomain Routing

Day 6: Local Dev & CI/CD
├── Morning: Docker Compose & Local Setup
└── Afternoon: CI/CD Pipeline

Day 7: Validation & Documentation
├── Morning: Monitoring & Validation
└── Afternoon: Documentation & Handoff
```

## Daily Breakdown (1 Week)

### Day 1: AWS & Terraform Backend (6-8 hours)
- ✅ AWS account + IAM user (1 hour)
- ✅ Domain + Route53 (30 min)
- ✅ GitHub repository (30 min)
- ✅ Terraform S3 backend (1 hour)
- ✅ DynamoDB locking (30 min)
- ✅ Terraform structure + init (1 hour)

### Day 2: VPC & ECR (6-8 hours)
- ✅ VPC module creation (2 hours)
- ✅ VPC deployment (1 hour)
- ✅ Security groups (1 hour)
- ✅ ECR repository (30 min)
- ✅ Test networking (1 hour)

### Day 3: ECS & ALB (6-8 hours)
- ✅ ECS module creation (2 hours)
- ✅ Minimal Docker image (1 hour)
- ✅ ALB module creation (2 hours)
- ✅ ACM certificate request (30 min)
- ✅ Deploy and test (1 hour)

### Day 4: Supabase & Database (6-8 hours)
- ✅ Supabase project (30 min)
- ✅ Connection strings + secrets (30 min)
- ✅ Backend initialization (1 hour)
- ✅ Schema creation (1 hour)
- ✅ Migration deployment (30 min)
- ✅ RLS policies (2 hours)
- ✅ Database testing (30 min)

### Day 5: Vercel & Edge Config (4-6 hours)
- ✅ Vercel project setup (1 hour)
- ✅ Next.js deployment (1 hour)
- ✅ Edge Config creation (30 min)
- ✅ Subdomain routing middleware (1 hour)
- ✅ Test deployment (30 min)

### Day 6: Local Dev & CI/CD (6-8 hours)
- ✅ Docker Compose setup (1 hour)
- ✅ Backend local setup (1 hour)
- ✅ Frontend local setup (1 hour)
- ✅ GitHub Actions workflow (2 hours)
- ✅ Test CI/CD pipeline (1 hour)

### Day 7: Validation & Docs (4-6 hours)
- ✅ Basic CloudWatch alarms (1 hour)
- ✅ Infrastructure validation (1 hour)
- ✅ RLS testing (30 min)
- ✅ README creation (1 hour)
- ✅ Setup documentation (1 hour)

## Critical Path Items

**Must Complete First**:
1. AWS account + IAM (Day 1)
2. Terraform backend (Day 2)
3. VPC deployment (Day 3-4)
4. Supabase setup (Day 7)

**Can Parallelize**:
- Vercel setup (Day 8) can start after Supabase
- Local dev environment (Day 9-10) can start after Day 7
- CI/CD (Day 11-12) can start after Day 8

## Estimated Time Investment (1 Week)

**Total Hours**: ~40-50 hours
- Day 1: 6-8 hours
- Day 2: 6-8 hours
- Day 3: 6-8 hours
- Day 4: 6-8 hours
- Day 5: 4-6 hours
- Day 6: 6-8 hours
- Day 7: 4-6 hours

**Team Allocation**:
- 1 Senior Engineer: Full-time focus (40-50 hrs/week)
- **OR** 2 Engineers: Split work (20-25 hrs each)

**Critical**: Full-time focus required for 1-week completion

## Risk Mitigation (1 Week)

**High-Risk Items**:
- Terraform backend (Day 1) - Test immediately, fix before proceeding
- Database schema (Day 4) - Test in local Postgres first
- CI/CD pipeline (Day 6) - Start with minimal workflow, expand later

**Contingency Strategy**:
- **No buffer time** - work evenings if needed
- **Skip non-essentials** - CloudFront, API Gateway can wait
- **Minimal configs** - Get it working, optimize later
- **Parallel work** - Use 2 engineers where possible

**If Behind Schedule**:
- Day 1-3: Must complete (blocking)
- Day 4: Database is critical
- Day 5: Vercel can be simplified
- Day 6: CI/CD can be basic
- Day 7: Documentation can be minimal

## Success Metrics (1 Week)

**By End of Day 1**:
- ✅ Terraform backend working
- ✅ Can run `terraform init` successfully

**By End of Day 2**:
- ✅ VPC deployed
- ✅ Can create resources in VPC

**By End of Day 3**:
- ✅ ECS cluster running
- ✅ ALB responding (even if 502, that's OK)

**By End of Day 4**:
- ✅ Database schema deployed
- ✅ Can connect and query database

**By End of Day 5**:
- ✅ Vercel deployment working
- ✅ Edge Config accessible

**By End of Day 6**:
- ✅ Local dev environment working
- ✅ CI/CD deploying automatically

**By End of Day 7**:
- ✅ All services validated
- ✅ Basic monitoring configured
- ✅ **READY FOR PHASE 2**

