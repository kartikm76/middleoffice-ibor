#!/bin/bash
set -e

# Deploy IBOR Analyst to AWS Demo Stack
# Minimal, single-AZ, cheapest configuration

AWS_REGION=${1:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🚀 IBOR Analyst AWS Demo Stack"
echo "=============================="
echo "Region: $AWS_REGION"
echo "Account: $ACCOUNT_ID"
echo ""

# 1. Collect inputs
echo "1️⃣  Gathering deployment parameters..."

read -sp "Database password (min 8 chars): " DB_PASSWORD
echo ""
if [ ${#DB_PASSWORD} -lt 8 ]; then
    echo "❌ Password must be at least 8 characters"
    exit 1
fi

read -sp "Anthropic API Key: " ANTHROPIC_KEY
echo ""
if [ -z "$ANTHROPIC_KEY" ]; then
    echo "❌ Anthropic API key is required"
    exit 1
fi

read -p "Docker Hub username (kartikm76): " DOCKER_USER
DOCKER_USER=${DOCKER_USER:-kartikm76}

# 2. Store secrets
echo ""
echo "2️⃣  Storing secrets..."

aws secretsmanager create-secret \
  --name ibor-demo/db-password \
  --secret-string "$DB_PASSWORD" \
  --region $AWS_REGION 2>/dev/null || \
aws secretsmanager update-secret \
  --secret-id ibor-demo/db-password \
  --secret-string "$DB_PASSWORD" \
  --region $AWS_REGION

aws secretsmanager create-secret \
  --name ibor-demo/anthropic-key \
  --secret-string "$ANTHROPIC_KEY" \
  --region $AWS_REGION 2>/dev/null || \
aws secretsmanager update-secret \
  --secret-id ibor-demo/anthropic-key \
  --secret-string "$ANTHROPIC_KEY" \
  --region $AWS_REGION

echo "✅ Secrets stored"

# 3. Deploy stack
echo ""
echo "3️⃣  Deploying CloudFormation stack..."

STACK_NAME="ibor-demo"

if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $AWS_REGION 2>/dev/null; then
    echo "ℹ️  Updating existing stack..."
    aws cloudformation update-stack \
      --stack-name $STACK_NAME \
      --template-body file://cloudformation/demo.yaml \
      --parameters \
        ParameterKey=DBPassword,ParameterValue=$DB_PASSWORD \
        ParameterKey=AnthropicApiKey,ParameterValue=$ANTHROPIC_KEY \
        ParameterKey=ContainerRegistry,ParameterValue=$DOCKER_USER \
      --region $AWS_REGION || echo "No updates needed"
else
    echo "📦 Creating new stack..."
    aws cloudformation create-stack \
      --stack-name $STACK_NAME \
      --template-body file://cloudformation/demo.yaml \
      --parameters \
        ParameterKey=DBPassword,ParameterValue=$DB_PASSWORD \
        ParameterKey=AnthropicApiKey,ParameterValue=$ANTHROPIC_KEY \
        ParameterKey=ContainerRegistry,ParameterValue=$DOCKER_USER \
      --region $AWS_REGION
fi

echo "⏳ Waiting for stack deployment (5-10 minutes)..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $AWS_REGION 2>/dev/null || \
aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $AWS_REGION 2>/dev/null || true

echo "✅ Stack deployed"

# 4. Get outputs
echo ""
echo "4️⃣  Retrieving stack outputs..."

ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $AWS_REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDnsName`].OutputValue' \
  --output text)

DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $AWS_REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`DatabaseEndpoint`].OutputValue' \
  --output text)

S3_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $AWS_REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
  --output text)

# 5. Summary
echo ""
echo "✅ DEPLOYMENT COMPLETE!"
echo "=============================="
echo ""
echo "📍 Access Points:"
echo "   Backend: http://$ALB_DNS"
echo "   API Docs: http://$ALB_DNS/docs"
echo "   Database: $DB_ENDPOINT:5432"
echo ""
echo "📝 Next Steps:"
echo ""
echo "1️⃣  Initialize database schema:"
echo "   psql -h $DB_ENDPOINT -U postgres -d ibordb < ibor-db/init/01-schema.sql"
echo "   (repeat for all SQL files in ibor-db/init/)"
echo ""
echo "2️⃣  Deploy frontend:"
echo "   npm run build --prefix ibor-ui"
echo "   aws s3 sync ibor-ui/dist s3://$S3_BUCKET/ --delete"
echo ""
echo "📊 Monitor:"
echo "   aws logs tail /ecs/ibor-demo --follow --region $AWS_REGION"
echo ""
echo "🗑️  Cleanup:"
echo "   aws cloudformation delete-stack --stack-name $STACK_NAME --region $AWS_REGION"
echo ""
