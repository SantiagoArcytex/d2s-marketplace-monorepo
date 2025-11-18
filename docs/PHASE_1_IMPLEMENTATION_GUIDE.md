# Phase 1: Foundations - Implementation Guide
## 1 Week: Complete Setup & Infrastructure

**Duration**: 1 week (5-7 days)  
**Team Size**: 1-2 engineers (full-time focus)  
**Prerequisites**: AWS account, domain name, GitHub/GitLab account  
**Priority**: Critical path only - essentials for Phase 2

---

## Table of Contents

1. [Overview](#overview)
2. [Day 1: AWS Setup & Terraform Backend](#day-1-aws-setup--terraform-backend)
3. [Day 2: VPC & ECR](#day-2-vpc--ecr)
4. [Day 3: ECS & ALB](#day-3-ecs--alb)
5. [Day 4: Supabase & Database](#day-4-supabase--database)
6. [Day 5: Vercel & Edge Config](#day-5-vercel--edge-config)
7. [Day 6: Local Dev & CI/CD](#day-6-local-dev--cicd)
8. [Day 7: Validation & Documentation](#day-7-validation--documentation)
9. [Success Criteria](#success-criteria)
10. [Troubleshooting Guide](#troubleshooting-guide)

---

## Overview

### Phase 1 Goals (1 Week)

By the end of Day 7, you will have:
- ✅ Complete AWS infrastructure deployed via Terraform
- ✅ Supabase database with schema and RLS policies
- ✅ Vercel project configured with Edge Config
- ✅ Basic CI/CD pipeline (deploy to staging)
- ✅ Local development environment
- ✅ Basic monitoring (CloudWatch)
- ✅ Ready for Phase 2 development

### Critical Path (1 Week)

```
Day 1: AWS + Terraform Backend
Day 2: VPC + ECR
Day 3: ECS + ALB
Day 4: Supabase + Database Schema
Day 5: Vercel + Edge Config
Day 6: Local Dev + Basic CI/CD
Day 7: Validation + Documentation
```

### Dependencies (Optimized for Speed)

**Sequential (Must Complete in Order)**:
1. AWS account + IAM setup (Day 1, Morning)
2. Terraform backend (Day 1, Afternoon)
3. VPC deployment (Day 2, Morning)
4. ECS cluster (Day 3)
5. Supabase + Schema (Day 4)
6. Vercel setup (Day 5)

**Parallel (Can Do Simultaneously)**:
- Local dev environment (Day 6, can start Day 4)
- CI/CD pipeline (Day 6, can start Day 5)
- Monitoring setup (Day 7, can start Day 6)

---

## Day 1: AWS Setup & Terraform Backend

**Time**: 6-8 hours  
**Goal**: AWS infrastructure ready, Terraform backend configured

### Morning (3-4 hours): AWS Account Setup

**Tasks**:
1. **Create AWS Account** (if not exists) - 30 min
   - Enable MFA on root account
   - Set up billing alerts ($100 threshold)
   - Enable Cost Explorer

2. **Create IAM User for Terraform** - 15 min
   ```bash
   # Create IAM user
   aws iam create-user --user-name terraform-user
   
   # Attach policies (PowerUserAccess for speed, restrict later)
   aws iam attach-user-policy \
     --user-name terraform-user \
     --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
   
   # Create access key
   aws iam create-access-key --user-name terraform-user
   # SAVE THESE CREDENTIALS SECURELY
   ```

3. **Configure AWS CLI** - 5 min
   ```bash
   aws configure --profile saas-marketplace
   # Enter Access Key ID
   # Enter Secret Access Key
   # Region: us-east-1
   # Output format: json
   ```

4. **Verify Access** - 2 min
   ```bash
   aws sts get-caller-identity --profile saas-marketplace
   ```

5. **Domain & DNS Setup** - 30 min
   ```bash
   # Create Route53 Hosted Zone (if domain not registered)
   aws route53 create-hosted-zone \
     --name platform.com \
     --caller-reference $(date +%s) \
     --profile saas-marketplace
   
   # Update nameservers at registrar if needed
   ```

6. **GitHub Repository** - 15 min
   ```bash
   git init
   git remote add origin https://github.com/your-org/saas-marketplace.git
   mkdir -p backend frontend terraform docs
   git add .
   git commit -m "Initial commit: Phase 1 setup"
   git push -u origin main
   ```

**Deliverable**: AWS account configured, domain ready, repo created

### Afternoon (3-4 hours): Terraform Backend

**Tasks**:
1. **Create S3 Bucket for State** - 10 min
   ```bash
   # Create bucket (use unique name with your account ID)
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   aws s3api create-bucket \
     --bucket saas-marketplace-terraform-state-${ACCOUNT_ID} \
     --region us-east-1 \
     --profile saas-marketplace
   
   # Enable versioning and encryption
   aws s3api put-bucket-versioning \
     --bucket saas-marketplace-terraform-state-${ACCOUNT_ID} \
     --versioning-configuration Status=Enabled \
     --profile saas-marketplace
   
   aws s3api put-bucket-encryption \
     --bucket saas-marketplace-terraform-state-${ACCOUNT_ID} \
     --server-side-encryption-configuration '{
       "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
     }' \
     --profile saas-marketplace
   ```

2. **Create DynamoDB Table** - 5 min
   ```bash
   aws dynamodb create-table \
     --table-name saas-marketplace-terraform-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region us-east-1 \
     --profile saas-marketplace
   ```

3. **Create Terraform Structure** - 10 min
   ```bash
   mkdir -p terraform/{environments/{staging,production},modules/{vpc,ecs,alb}}
   ```

4. **Create Backend Configuration** - 15 min
   
   **File**: `terraform/environments/staging/backend.tf`
   ```hcl
   terraform {
     required_version = ">= 1.6.0"
     backend "s3" {
       bucket         = "saas-marketplace-terraform-state-${ACCOUNT_ID}"
       key            = "staging/terraform.tfstate"
       region         = "us-east-1"
       encrypt        = true
       dynamodb_table = "saas-marketplace-terraform-locks"
       profile        = "saas-marketplace"
     }
   }
   ```

5. **Test Terraform Init** - 5 min
   ```bash
   cd terraform/environments/staging
   terraform init
   # Should successfully initialize
   ```

**Deliverable**: Terraform backend working, ready for infrastructure deployment

---

## Day 2: VPC & ECR

**Time**: 6-8 hours  
**Goal**: Networking infrastructure deployed, ECR ready

### Morning (3-4 hours): VPC Module

**Tasks**:
1. **Create VPC Module** - 1 hour
   
   **File**: `terraform/modules/vpc/main.tf`
   ```hcl
   resource "aws_vpc" "main" {
     cidr_block           = var.vpc_cidr
     enable_dns_hostnames = true
     enable_dns_support   = true
     tags = { Name = "${var.project_name}-${var.environment}-vpc" }
   }
   
   resource "aws_subnet" "public" {
     count = 2
     vpc_id                  = aws_vpc.main.id
     cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
     availability_zone       = var.availability_zones[count.index]
     map_public_ip_on_launch = true
     tags = { Name = "${var.project_name}-${var.environment}-public-${count.index + 1}" }
   }
   
   resource "aws_subnet" "private" {
     count = 2
     vpc_id            = aws_vpc.main.id
     cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 2)
     availability_zone = var.availability_zones[count.index]
     tags = { Name = "${var.project_name}-${var.environment}-private-${count.index + 1}" }
   }
   
   resource "aws_internet_gateway" "main" {
     vpc_id = aws_vpc.main.id
     tags = { Name = "${var.project_name}-${var.environment}-igw" }
   }
   
   resource "aws_eip" "nat" {
     count  = 2
     domain = "vpc"
     tags = { Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}" }
   }
   
   resource "aws_nat_gateway" "main" {
     count         = 2
     allocation_id = aws_eip.nat[count.index].id
     subnet_id     = aws_subnet.public[count.index].id
     tags = { Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}" }
   }
   
   resource "aws_route_table" "public" {
     vpc_id = aws_vpc.main.id
     route {
       cidr_block = "0.0.0.0/0"
       gateway_id = aws_internet_gateway.main.id
     }
     tags = { Name = "${var.project_name}-${var.environment}-public-rt" }
   }
   
   resource "aws_route_table_association" "public" {
     count = 2
     subnet_id      = aws_subnet.public[count.index].id
     route_table_id = aws_route_table.public.id
   }
   
   resource "aws_route_table" "private" {
     count  = 2
     vpc_id = aws_vpc.main.id
     route {
       cidr_block     = "0.0.0.0/0"
       nat_gateway_id = aws_nat_gateway.main[count.index].id
     }
     tags = { Name = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}" }
   }
   
   resource "aws_route_table_association" "private" {
     count = 2
     subnet_id      = aws_subnet.private[count.index].id
     route_table_id = aws_route_table.private[count.index].id
   }
   ```

   **File**: `terraform/modules/vpc/variables.tf`
   ```hcl
   variable "project_name" { type = string }
   variable "environment" { type = string }
   variable "vpc_cidr" { type = string; default = "10.0.0.0/16" }
   variable "availability_zones" { type = list(string); default = ["us-east-1a", "us-east-1b"] }
   ```

   **File**: `terraform/modules/vpc/outputs.tf`
   ```hcl
   output "vpc_id" { value = aws_vpc.main.id }
   output "public_subnet_ids" { value = aws_subnet.public[*].id }
   output "private_subnet_ids" { value = aws_subnet.private[*].id }
   ```

2. **Create Staging Environment** - 30 min
   
   **File**: `terraform/environments/staging/main.tf`
   ```hcl
   terraform {
     required_version = ">= 1.6.0"
     required_providers {
       aws = { source = "hashicorp/aws"; version = "~> 5.0" }
     }
     backend "s3" {
       bucket         = "saas-marketplace-terraform-state-${ACCOUNT_ID}"
       key            = "staging/terraform.tfstate"
       region         = "us-east-1"
       encrypt        = true
       dynamodb_table = "saas-marketplace-terraform-locks"
     }
   }
   
   provider "aws" {
     region  = "us-east-1"
     profile = "saas-marketplace"
   }
   
   module "vpc" {
     source = "../../modules/vpc"
     project_name = "saas-marketplace"
     environment  = "staging"
     vpc_cidr     = "10.1.0.0/16"
     availability_zones = ["us-east-1a", "us-east-1b"]
   }
   ```

3. **Deploy VPC** - 30 min
   ```bash
   cd terraform/environments/staging
   terraform init
   terraform plan
   terraform apply -auto-approve
   ```

**Deliverable**: VPC deployed in staging

### Afternoon (3-4 hours): ECR & Security Groups

**Tasks**:
1. **Create ECR Repository** - 5 min
   ```bash
   aws ecr create-repository \
     --repository-name saas-marketplace-api \
     --region us-east-1 \
     --profile saas-marketplace
   ```

2. **Create Security Groups Module** - 1 hour
   
   **File**: `terraform/modules/security-groups/main.tf`
   ```hcl
   resource "aws_security_group" "alb" {
     name_prefix = "${var.project_name}-${var.environment}-alb-"
     vpc_id      = var.vpc_id
     ingress {
       from_port   = 443
       to_port     = 443
       protocol    = "tcp"
       cidr_blocks = ["0.0.0.0/0"]
     }
     ingress {
       from_port   = 80
       to_port     = 80
       protocol    = "tcp"
       cidr_blocks = ["0.0.0.0/0"]
     }
     egress {
       from_port   = 0
       to_port     = 0
       protocol    = "-1"
       cidr_blocks = ["0.0.0.0/0"]
     }
   }
   
   resource "aws_security_group" "ecs_tasks" {
     name_prefix = "${var.project_name}-${var.environment}-ecs-"
     vpc_id      = var.vpc_id
     ingress {
       from_port       = 3000
       to_port         = 3000
       protocol        = "tcp"
       security_groups = [aws_security_group.alb.id]
     }
     egress {
       from_port   = 0
       to_port     = 0
       protocol    = "-1"
       cidr_blocks = ["0.0.0.0/0"]
     }
   }
   ```

3. **Update Staging Configuration** - 30 min
   - Add security groups module to staging
   - Deploy security groups

**Deliverable**: ECR created, security groups deployed

---

## Day 3: ECS & ALB

**Time**: 6-8 hours  
**Goal**: ECS cluster running, ALB configured with SSL

### Morning (3-4 hours): ECS Module

**Tasks**:
1. **Create ECS Module** - 2 hours
   
   **File**: `terraform/modules/ecs/main.tf` (simplified for speed)
   ```hcl
   resource "aws_ecs_cluster" "main" {
     name = "${var.project_name}-${var.environment}"
     setting { name = "containerInsights"; value = "enabled" }
   }
   
   resource "aws_cloudwatch_log_group" "ecs" {
     name              = "/ecs/${var.project_name}-${var.environment}"
     retention_in_days = 7
   }
   
   resource "aws_iam_role" "ecs_task_execution" {
     name = "${var.project_name}-${var.environment}-ecs-execution"
     assume_role_policy = jsonencode({
       Version = "2012-10-17"
       Statement = [{
         Action = "sts:AssumeRole"
         Effect = "Allow"
         Principal = { Service = "ecs-tasks.amazonaws.com" }
       }]
     })
   }
   
   resource "aws_iam_role_policy_attachment" "ecs_execution" {
     role       = aws_iam_role.ecs_task_execution.name
     policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
   }
   
   resource "aws_ecs_task_definition" "api" {
     family                   = "${var.project_name}-${var.environment}-api"
     network_mode             = "awsvpc"
     requires_compatibilities = ["FARGATE"]
     cpu                      = 512
     memory                   = 1024
     execution_role_arn       = aws_iam_role.ecs_task_execution.arn
     container_definitions = jsonencode([{
       name  = "api"
       image = "${var.ecr_repository_url}:${var.image_tag}"
       portMappings = [{ containerPort = 3000; protocol = "tcp" }]
       environment = [{ name = "NODE_ENV", value = var.environment }]
       logConfiguration = {
         logDriver = "awslogs"
         options = {
           "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
           "awslogs-region"        = var.aws_region
           "awslogs-stream-prefix" = "api"
         }
       }
       healthCheck = {
         command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
         interval    = 30
         timeout     = 5
         retries     = 3
         startPeriod = 60
       }
     }])
   }
   
   resource "aws_ecs_service" "api" {
     name            = "${var.project_name}-${var.environment}-api"
     cluster         = aws_ecs_cluster.main.id
     task_definition = aws_ecs_task_definition.api.arn
     desired_count   = 1
     launch_type     = "FARGATE"
     network_configuration {
       subnets          = var.private_subnet_ids
       security_groups  = [var.ecs_security_group_id]
       assign_public_ip = false
     }
     load_balancer {
       target_group_arn = var.target_group_arn
       container_name   = "api"
       container_port   = 3000
     }
   }
   ```

2. **Create Minimal Docker Image** - 30 min
   
   **File**: `backend/Dockerfile`
   ```dockerfile
   FROM node:20-alpine
   WORKDIR /app
   COPY package*.json ./
   RUN npm ci --only=production
   COPY . .
   RUN npm run build
   EXPOSE 3000
   CMD ["node", "dist/main.js"]
   ```
   
   **Build and Push** (placeholder image):
   ```bash
   cd backend
   docker build -t saas-marketplace-api:latest .
   aws ecr get-login-password --region us-east-1 | \
     docker login --username AWS --password-stdin \
     ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
   docker tag saas-marketplace-api:latest \
     ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/saas-marketplace-api:latest
   docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/saas-marketplace-api:latest
   ```

**Deliverable**: ECS module created, placeholder image pushed

### Afternoon (3-4 hours): ALB Module

**Tasks**:
1. **Create ALB Module** - 2 hours
   
   **File**: `terraform/modules/alb/main.tf`
   ```hcl
   resource "aws_lb" "main" {
     name               = "${var.project_name}-${var.environment}-alb"
     internal           = false
     load_balancer_type = "application"
     security_groups    = [var.alb_security_group_id]
     subnets            = var.public_subnet_ids
     enable_deletion_protection = false
   }
   
   resource "aws_lb_target_group" "api" {
     name     = "${var.project_name}-${var.environment}-api-tg"
     port     = 3000
     protocol = "HTTP"
     vpc_id   = var.vpc_id
     target_type = "ip"
     health_check {
       enabled             = true
       healthy_threshold   = 2
       unhealthy_threshold = 3
       timeout             = 5
       interval            = 30
       path                = "/health"
       protocol            = "HTTP"
       matcher             = "200"
     }
   }
   
   resource "aws_lb_listener" "https" {
     load_balancer_arn = aws_lb.main.arn
     port              = "443"
     protocol          = "HTTPS"
     ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
     certificate_arn   = var.acm_certificate_arn
     default_action {
       type             = "forward"
       target_group_arn = aws_lb_target_group.api.arn
     }
   }
   
   resource "aws_lb_listener" "http" {
     load_balancer_arn = aws_lb.main.arn
     port              = "80"
     protocol          = "HTTP"
     default_action {
       type = "redirect"
       redirect {
         port        = "443"
         protocol    = "HTTPS"
         status_code = "HTTP_301"
       }
     }
   }
   ```

2. **Request ACM Certificate** - 15 min
   ```bash
   # Request certificate (use staging subdomain for now)
   aws acm request-certificate \
     --domain-name api-staging.platform.com \
     --validation-method DNS \
     --region us-east-1 \
     --profile saas-marketplace
   
   # Get validation records
   aws acm describe-certificate \
     --certificate-arn <CERT_ARN> \
     --region us-east-1
   
   # Add DNS validation records to Route53
   ```

3. **Deploy ALB** - 30 min
   - Add ALB module to staging
   - Deploy ALB and target group
   - Verify health checks

**Deliverable**: ALB deployed, SSL certificate configured

---

## Day 4: Supabase & Database

**Time**: 6-8 hours  
**Goal**: Database schema deployed, RLS policies configured

### Morning (3-4 hours): Supabase Setup

**Tasks**:
1. **Create Supabase Project** - 30 min
   - Go to https://supabase.com
   - Create project: `saas-marketplace-staging`
   - Region: `us-east-1`
   - Plan: Pro ($25/month) - required for connection pooling
   - **Save database password securely**

2. **Get Connection Strings** - 10 min
   ```bash
   # Transaction mode (for queries) - Port 6543
   DATABASE_URL="postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:6543/postgres?pgbouncer=true"
   
   # Session mode (for transactions) - Port 5432
   SESSION_DATABASE_URL="postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"
   ```

3. **Store in AWS Secrets Manager** - 10 min
   ```bash
   aws secretsmanager create-secret \
     --name saas-marketplace/staging/database-url \
     --secret-string "{\"url\":\"$DATABASE_URL\"}" \
     --profile saas-marketplace
   
   aws secretsmanager create-secret \
     --name saas-marketplace/staging/database-session-url \
     --secret-string "{\"url\":\"$SESSION_DATABASE_URL\"}" \
     --profile saas-marketplace
   ```

4. **Get Supabase API Keys** - 5 min
   - Copy `anon` key and `service_role` key from Supabase dashboard
   - Store in Secrets Manager

**Deliverable**: Supabase project created, credentials stored

### Afternoon (3-4 hours): Database Schema

**Tasks**:
1. **Initialize Backend Project** - 30 min
   ```bash
   cd backend
   npm init -y
   npm install drizzle-orm drizzle-kit postgres
   npm install -D @types/node typescript ts-node
   ```

2. **Create Schema File** - 1 hour
   
   **File**: `backend/src/db/schema.ts`
   ```typescript
   // Copy complete schema from SYSTEM_DESIGN_DOCUMENT.md Section 4.1
   // Include: tenants, users, userRoles, apps, subscriptions, webhookLogs
   ```

3. **Create Drizzle Config** - 15 min
   
   **File**: `backend/drizzle.config.ts`
   ```typescript
   import type { Config } from 'drizzle-kit';
   
   export default {
     schema: './src/db/schema.ts',
     out: './drizzle',
     driver: 'pg',
     dbCredentials: {
       connectionString: process.env.SESSION_DATABASE_URL!,
     },
   } satisfies Config;
   ```

4. **Generate and Apply Migration** - 30 min
   ```bash
   # Generate migration
   npx drizzle-kit generate:pg
   
   # Apply migration (use session mode URL)
   npx drizzle-kit push:pg
   ```

5. **Set Up RLS Policies** - 1 hour
   
   **In Supabase SQL Editor**, run:
   ```sql
   -- Create enum
   CREATE TYPE public.app_role AS ENUM ('admin', 'moderator', 'user');
   
   -- Security definer function
   CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
   RETURNS BOOLEAN
   LANGUAGE SQL
   STABLE
   SECURITY DEFINER
   SET search_path = public
   AS $$
     SELECT EXISTS (
       SELECT 1 FROM public.user_roles
       WHERE user_id = _user_id AND role = _role
     )
   $$;
   
   -- Enable RLS on all tables
   ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
   ALTER TABLE users ENABLE ROW LEVEL SECURITY;
   ALTER TABLE apps ENABLE ROW LEVEL SECURITY;
   ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
   
   -- Create RLS policies (copy from SDD Section 4.2)
   ```

6. **Test Database Connection** - 15 min
   ```bash
   # Create test script
   # backend/test-db.ts
   import { drizzle } from 'drizzle-orm/postgres-js';
   import postgres from 'postgres';
   
   const client = postgres(process.env.DATABASE_URL!);
   const db = drizzle(client);
   
   // Test query
   const result = await db.execute('SELECT 1');
   console.log('Database connected:', result);
   ```

**Deliverable**: Database schema deployed, RLS policies configured

---

## Day 5: Vercel & Edge Config

**Time**: 4-6 hours  
**Goal**: Vercel project configured, Edge Config ready

### Morning (2-3 hours): Vercel Project Setup

**Tasks**:
1. **Install Vercel CLI** - 5 min
   ```bash
   npm install -g vercel
   ```

2. **Login and Link Project** - 10 min
   ```bash
   vercel login
   cd frontend
   vercel link
   # Follow prompts to create/link project
   ```

3. **Create Minimal Next.js App** - 30 min
   ```bash
   cd frontend
   npx create-next-app@latest . --typescript --tailwind --app --yes
   ```

4. **Configure Environment Variables** - 15 min
   ```bash
   # In Vercel dashboard or via CLI
   vercel env add NEXT_PUBLIC_SUPABASE_URL production
   vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY production
   vercel env add NEXT_PUBLIC_API_URL production
   ```

5. **Test Deployment** - 15 min
   ```bash
   vercel --prod
   # Should deploy successfully
   ```

**Deliverable**: Vercel project configured and deployed

### Afternoon (2-3 hours): Edge Config & Subdomain Routing

**Tasks**:
1. **Create Edge Config** - 10 min
   ```bash
   vercel edge-config create subdomain-routing
   # Save Edge Config ID and token
   ```

2. **Create Edge Middleware** - 1 hour
   
   **File**: `frontend/middleware.ts`
   ```typescript
   import { NextRequest, NextResponse } from 'next/server';
   import { get } from '@vercel/edge-config';
   
   export const config = {
     matcher: '/((?!api|_next/static|_next/image|favicon.ico).*)',
   };
   
   export async function middleware(req: NextRequest) {
     const hostname = req.headers.get('host') || '';
     const subdomain = hostname.split('.')[0];
     
     // Skip platform domains
     if (['www', 'api', 'platform'].includes(subdomain)) {
       return NextResponse.next();
     }
     
     // Lookup in Edge Config
     const appConfig = await get(`subdomain-routing:${subdomain}`);
     
     if (!appConfig) {
       return new NextResponse('App not found', { status: 404 });
     }
     
     // Rewrite to app route
     const url = req.nextUrl.clone();
     url.pathname = `/apps/${subdomain}${url.pathname}`;
     return NextResponse.rewrite(url);
   }
   ```

3. **Test Edge Config** - 30 min
   ```typescript
   // Test script
   import { get } from '@vercel/edge-config';
   
   // Add test entry via Vercel dashboard
   // Then test lookup
   const app = await get('subdomain-routing:test');
   console.log('Edge Config test:', app);
   ```

4. **Configure Domain in Vercel** - 30 min
   - Add domain in Vercel dashboard
   - Configure DNS records
   - Test subdomain routing

**Deliverable**: Edge Config created, subdomain routing working

---

## Day 6: Local Dev & CI/CD

**Time**: 6-8 hours  
**Goal**: Local environment working, CI/CD deploying automatically

### Morning (3-4 hours): Local Development Environment

**Tasks**:
1. **Create Docker Compose** - 30 min
   
   **File**: `docker-compose.yml`
   ```yaml
   version: '3.9'
   services:
     postgres:
       image: postgres:15-alpine
       environment:
         POSTGRES_DB: saas_marketplace
         POSTGRES_USER: postgres
         POSTGRES_PASSWORD: postgres
       ports:
         - "5432:5432"
       volumes:
         - postgres_data:/var/lib/postgresql/data
     
     redis:
       image: redis:7-alpine
       ports:
         - "6379:6379"
     
     api:
       build: ./backend
       ports:
         - "3001:3000"
       environment:
         DATABASE_URL: postgresql://postgres:postgres@postgres:5432/saas_marketplace
         REDIS_URL: redis://redis:6379
         NODE_ENV: development
       volumes:
         - ./backend:/app
       depends_on:
         - postgres
         - redis
     
     web:
       build: ./frontend
       ports:
         - "3000:3000"
       environment:
         NEXT_PUBLIC_API_URL: http://localhost:3001
       volumes:
         - ./frontend:/app
   volumes:
     postgres_data:
   ```

2. **Start Services** - 10 min
   ```bash
   docker-compose up -d
   docker-compose ps  # Verify all services running
   ```

3. **Initialize NestJS Backend** - 1 hour
   ```bash
   cd backend
   npm install -g @nestjs/cli
   nest new . --skip-git --package-manager npm
   
   # Install core dependencies
   npm install drizzle-orm postgres @trpc/server zod
   npm install -D @types/node typescript ts-node
   
   # Create basic structure
   mkdir -p src/{db,trpc,modules}
   ```

4. **Create Minimal Backend** - 1 hour
   
   **File**: `backend/src/main.ts`
   ```typescript
   import { NestFactory } from '@nestjs/core';
   import { AppModule } from './app.module';
   
   async function bootstrap() {
     const app = await NestFactory.create(AppModule);
     app.enableCors();
     await app.listen(3000);
   }
   bootstrap();
   ```
   
   **File**: `backend/src/app.module.ts`
   ```typescript
   import { Module } from '@nestjs/common';
   
   @Module({
     imports: [],
     controllers: [],
     providers: [],
   })
   export class AppModule {}
   ```
   
   **Add Health Endpoint**:
   ```typescript
   // backend/src/app.controller.ts
   import { Controller, Get } from '@nestjs/common';
   
   @Controller()
   export class AppController {
     @Get('health')
     health() {
       return { status: 'ok', timestamp: new Date().toISOString() };
     }
   }
   ```

5. **Test Backend Locally** - 15 min
   ```bash
   cd backend
   npm run start:dev
   curl http://localhost:3000/health
   # Should return: {"status":"ok","timestamp":"..."}
   ```

**Deliverable**: Local development environment working

### Afternoon (3-4 hours): CI/CD Pipeline

**Tasks**:
1. **Create GitHub Actions Workflow** - 1 hour
   
   **File**: `.github/workflows/deploy.yml`
   ```yaml
   name: Deploy to Staging
   
   on:
     push:
       branches: [main]
   
   env:
     AWS_REGION: us-east-1
   
   jobs:
     deploy-backend:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         
         - name: Configure AWS credentials
           uses: aws-actions/configure-aws-credentials@v4
           with:
             aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
             aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
             aws-region: ${{ env.AWS_REGION }}
         
         - name: Login to ECR
           run: |
             aws ecr get-login-password --region ${{ env.AWS_REGION }} | \
               docker login --username AWS --password-stdin \
               ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com
         
         - name: Build and push Docker image
           run: |
             cd backend
             docker build -t saas-marketplace-api:${{ github.sha }} .
             docker tag saas-marketplace-api:${{ github.sha }} \
               ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com/saas-marketplace-api:${{ github.sha }}
             docker push ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com/saas-marketplace-api:${{ github.sha }}
         
         - name: Deploy to ECS
           run: |
             aws ecs update-service \
               --cluster saas-marketplace-staging \
               --service api \
               --force-new-deployment \
               --region ${{ env.AWS_REGION }}
     
     deploy-frontend:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         
         - name: Setup Node.js
           uses: actions/setup-node@v4
           with:
             node-version: '20'
         
         - name: Install Vercel CLI
           run: npm install -g vercel
         
         - name: Deploy to Vercel
           run: |
             cd frontend
             vercel --prod --token ${{ secrets.VERCEL_TOKEN }}
           env:
             VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
             VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
   ```

2. **Configure GitHub Secrets** - 15 min
   - Go to repository Settings → Secrets
   - Add: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ACCOUNT_ID`
   - Add: `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`

3. **Test CI/CD Pipeline** - 30 min
   ```bash
   git add .
   git commit -m "Add CI/CD pipeline"
   git push origin main
   # Watch GitHub Actions run
   ```

4. **Add Basic Security Scanning** - 1 hour
   
   **Add to workflow**:
   ```yaml
   security-scan:
     runs-on: ubuntu-latest
     steps:
       - uses: actions/checkout@v4
       - name: Run Snyk
         uses: snyk/actions/node@master
         env:
           SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
   ```

**Deliverable**: CI/CD pipeline working, auto-deploying to staging

---

## Day 7: Validation & Documentation

**Time**: 4-6 hours  
**Goal**: Everything validated, documentation complete, ready for Phase 2

### Morning (2-3 hours): Basic Monitoring & Validation

**Tasks**:
1. **Set Up Basic CloudWatch Alarms** - 1 hour
   ```bash
   # Create SNS topic
   aws sns create-topic --name saas-marketplace-alarms
   
   # Subscribe email
   aws sns subscribe \
     --topic-arn arn:aws:sns:us-east-1:ACCOUNT:saas-marketplace-alarms \
     --protocol email \
     --notification-endpoint your-email@example.com
   
   # Create basic alarm for ECS service
   aws cloudwatch put-metric-alarm \
     --alarm-name ecs-service-unhealthy \
     --alarm-description "ECS service has unhealthy tasks" \
     --metric-name HealthyHostCount \
     --namespace AWS/ECS \
     --statistic Average \
     --period 60 \
     --threshold 1 \
     --comparison-operator LessThanThreshold \
     --evaluation-periods 2 \
     --alarm-actions arn:aws:sns:us-east-1:ACCOUNT:saas-marketplace-alarms
   ```

2. **Validate Infrastructure** - 1 hour
   ```bash
   # Check ECS service
   aws ecs describe-services \
     --cluster saas-marketplace-staging \
     --services api \
     --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'
   
   # Test ALB health
   ALB_DNS=$(aws elbv2 describe-load-balancers \
     --query 'LoadBalancers[?LoadBalancerName==`saas-marketplace-staging-alb`].DNSName' \
     --output text)
   curl -f http://${ALB_DNS}/health || echo "Health check failed"
   
   # Test database connection
   cd backend
   npm run db:test  # Create simple test script
   ```

3. **Verify RLS Policies** - 30 min
   ```sql
   -- In Supabase SQL Editor
   -- Test tenant isolation
   SET app.tenant_id = 'test-tenant-1';
   SELECT * FROM apps; -- Should only return apps for tenant-1
   
   -- Test without tenant context (should fail or return empty)
   RESET app.tenant_id;
   SELECT * FROM apps; -- Should be blocked by RLS
   ```

**Deliverable**: Basic monitoring configured, infrastructure validated

### Afternoon (2-3 hours): Documentation & Handoff

**Tasks**:
1. **Create README** - 1 hour
   
   **File**: `README.md`
   ```markdown
   # SaaS Marketplace Platform
   
   ## Quick Start
   
   ### Prerequisites
   - Node.js 20+
   - Docker & Docker Compose
   - AWS CLI configured
   - Terraform 1.6+
   
   ### Local Development
   ```bash
   docker-compose up -d
   cd backend && npm install && npm run dev
   cd frontend && npm install && npm run dev
   ```
   
   ### Infrastructure
   ```bash
   cd terraform/environments/staging
   terraform init
   terraform plan
   terraform apply
   ```
   
   ## Architecture
   See SYSTEM_DESIGN_DOCUMENT.md
   ```

2. **Create Environment Setup Guide** - 1 hour
   
   **File**: `docs/SETUP.md`
   - Step-by-step setup instructions
   - Environment variable reference
   - Common issues and solutions

3. **Document API Endpoints** - 30 min
   - Health check endpoint
   - Future tRPC endpoints (placeholder)

4. **Create Deployment Checklist** - 30 min
   
   **File**: `docs/DEPLOYMENT_CHECKLIST.md`
   ```markdown
   ## Pre-Deployment
   - [ ] All tests passing
   - [ ] Environment variables configured
   - [ ] Database migrations applied
   - [ ] Terraform plan reviewed
   
   ## Deployment
   - [ ] Deploy infrastructure (Terraform)
   - [ ] Deploy backend (ECS)
   - [ ] Deploy frontend (Vercel)
   - [ ] Verify health checks
   
   ## Post-Deployment
   - [ ] Test all endpoints
   - [ ] Verify monitoring
   - [ ] Check logs
   ```

**Deliverable**: Documentation complete, ready for Phase 2

---

## Success Criteria

### Day 1 Checklist
- [ ] AWS account configured with IAM user
- [ ] Domain registered and Route53 configured
- [ ] GitHub repository created with structure
- [ ] Terraform backend (S3 + DynamoDB) created
- [ ] Terraform init successful

### Day 2 Checklist
- [ ] VPC module created
- [ ] VPC deployed in staging
- [ ] Security groups created
- [ ] ECR repository created

### Day 3 Checklist
- [ ] ECS module created
- [ ] ECS cluster deployed
- [ ] ALB module created
- [ ] ALB deployed with target group
- [ ] ACM certificate requested (validation can complete later)

### Day 4 Checklist
- [ ] Supabase project created
- [ ] Database schema deployed via Drizzle
- [ ] RLS policies configured
- [ ] Connection strings stored in Secrets Manager
- [ ] Database connection tested

### Day 5 Checklist
- [ ] Vercel project created and linked
- [ ] Next.js app deployed to Vercel
- [ ] Edge Config created
- [ ] Subdomain routing middleware created
- [ ] Environment variables configured

### Day 6 Checklist
- [ ] Docker Compose working locally
- [ ] Backend running locally (health endpoint)
- [ ] Frontend running locally
- [ ] CI/CD pipeline created
- [ ] GitHub Actions workflow tested
- [ ] Auto-deployment to staging working

### Day 7 Checklist
- [ ] Basic CloudWatch alarms configured
- [ ] All services validated (ECS, ALB, Database, Vercel)
- [ ] RLS policies tested
- [ ] README.md created
- [ ] Setup documentation complete
- [ ] Ready for Phase 2 development

---

## Troubleshooting Guide

### Common Issues

#### Issue: Terraform Backend Access Denied
**Solution**:
```bash
# Verify IAM permissions
aws iam get-user --user-name terraform-user
# Ensure PowerUserAccess or equivalent policy attached
```

#### Issue: ECS Tasks Not Starting
**Solution**:
```bash
# Check task logs
aws logs tail /ecs/saas-marketplace-production --follow

# Verify secrets access
aws secretsmanager get-secret-value \
  --secret-id saas-marketplace/production/database-url
```

#### Issue: Database Connection Failures
**Solution**:
- Verify connection string format
- Check Supabase firewall rules
- Ensure using correct port (6543 for transaction mode, 5432 for session mode)

#### Issue: Vercel Deployment Fails
**Solution**:
```bash
# Check build logs
vercel logs

# Verify environment variables
vercel env ls
```

#### Issue: CI/CD Pipeline Fails
**Solution**:
- Check GitHub Actions logs
- Verify all secrets are configured
- Ensure AWS credentials are correct

---

## Next Steps After Phase 1

Once Phase 1 is complete (Day 7), proceed immediately to:
- **Phase 2**: Core Features Development
  - Authentication implementation (Supabase Auth)
  - Multi-tenancy layer (tenant context middleware)
  - App management (tRPC routers)
  - Payment integration (GoHighLevel webhooks)
  - Real-time notifications (Redis pub/sub)

**You now have a solid foundation to build upon!**

---

## Resources

### Documentation
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Supabase Documentation](https://supabase.com/docs)
- [Vercel Documentation](https://vercel.com/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Tools
- [AWS CLI](https://aws.amazon.com/cli/)
- [Terraform](https://www.terraform.io/downloads)
- [Vercel CLI](https://vercel.com/docs/cli)
- [Drizzle Kit](https://orm.drizzle.team/docs/kit-docs/overview)

---

## Time Optimization Tips

### Parallel Work
- **Day 4-5**: Supabase setup and Vercel setup can overlap
- **Day 6**: Local dev and CI/CD can be done in parallel by 2 people
- **Day 7**: Monitoring and documentation can be parallel

### Speed Optimizations
1. **Use Staging First**: Don't create production until staging works
2. **Minimal Configs**: Start with minimal Terraform configs, expand later
3. **Skip Non-Essentials**: 
   - Skip CloudFront (add in Phase 2)
   - Skip API Gateway (add in Phase 2)
   - Skip advanced monitoring (basic CloudWatch is enough)
4. **Use Defaults**: Accept default values where possible
5. **Automate**: Use scripts for repetitive tasks

### Critical Path Items (Must Complete)
1. ✅ Terraform backend (Day 1)
2. ✅ VPC (Day 2)
3. ✅ ECS + ALB (Day 3)
4. ✅ Database schema (Day 4)
5. ✅ Vercel + Edge Config (Day 5)
6. ✅ Local dev working (Day 6)
7. ✅ CI/CD deploying (Day 6)

### Can Defer to Phase 2
- CloudFront CDN
- API Gateway
- Advanced monitoring (Datadog, Sentry)
- WAF configuration
- Auto-scaling policies
- Multi-region setup

---

**End of Phase 1 Implementation Guide (1 Week Version)**

