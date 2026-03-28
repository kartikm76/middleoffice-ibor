#!/bin/bash
set -e

# Deploy ibor-analyst to AWS using CloudFormation
# Usage: ./scripts/deploy-to-aws.sh [environment] [region]

ENVIRONMENT=${1:-production}
AWS_REGION=${2:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🚀 IBOR Analyst AWS CloudFormation Deployment"
echo "=============================================="
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Account: $ACCOUNT_ID"
echo ""

# 1. Collect parameters
echo "1️⃣  Collecting deployment parameters..."

read -p "Database instance class (db.t3.micro): " DB_INSTANCE_CLASS
DB_INSTANCE_CLASS=${DB_INSTANCE_CLASS:-db.t3.micro}

read -p "Database name (ibordb): " DB_NAME
DB_NAME=${DB_NAME:-ibordb}

read -p "Database username (postgres): " DB_USERNAME
DB_USERNAME=${DB_USERNAME:-postgres}

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

read -p "Container registry (kartikm76): " CONTAINER_REGISTRY
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-kartikm76}

# 2. Create parameter file
echo ""
echo "2️⃣  Creating CloudFormation parameters..."

cat > /tmp/cf-params.json <<EOF
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "$ENVIRONMENT"
  },
  {
    "ParameterKey": "DBInstanceClass",
    "ParameterValue": "$DB_INSTANCE_CLASS"
  },
  {
    "ParameterKey": "DBName",
    "ParameterValue": "$DB_NAME"
  },
  {
    "ParameterKey": "DBUsername",
    "ParameterValue": "$DB_USERNAME"
  },
  {
    "ParameterKey": "DBPassword",
    "ParameterValue": "$DB_PASSWORD"
  },
  {
    "ParameterKey": "AnthropicApiKey",
    "ParameterValue": "$ANTHROPIC_KEY"
  },
  {
    "ParameterKey": "ContainerRegistry",
    "ParameterValue": "$CONTAINER_REGISTRY"
  }
]
EOF

# 3. Store secrets
echo ""
echo "3️⃣  Storing secrets in AWS Secrets Manager..."

aws secretsmanager create-secret \
  --name ibor/$ENVIRONMENT/db-password \
  --secret-string "$DB_PASSWORD" \
  --region $AWS_REGION 2>/dev/null || \
aws secretsmanager update-secret \
  --secret-id ibor/$ENVIRONMENT/db-password \
  --secret-string "$DB_PASSWORD" \
  --region $AWS_REGION

aws secretsmanager create-secret \
  --name ibor/$ENVIRONMENT/anthropic-api-key \
  --secret-string "$ANTHROPIC_KEY" \
  --region $AWS_REGION 2>/dev/null || \
aws secretsmanager update-secret \
  --secret-id ibor/$ENVIRONMENT/anthropic-api-key \
  --secret-string "$ANTHROPIC_KEY" \
  --region $AWS_REGION

echo "✅ Secrets stored"

# 4. Deploy Network Stack
echo ""
echo "4️⃣  Deploying Network Stack..."

NETWORK_STACK="ibor-network-$ENVIRONMENT"

if aws cloudformation describe-stacks --stack-name $NETWORK_STACK --region $AWS_REGION 2>/dev/null; then
    echo "ℹ️  Updating existing stack..."
    aws cloudformation update-stack \
      --stack-name $NETWORK_STACK \
      --template-body file://cloudformation/1-network.yaml \
      --parameters ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
      --region $AWS_REGION
else
    echo "📦 Creating new stack..."
    aws cloudformation create-stack \
      --stack-name $NETWORK_STACK \
      --template-body file://cloudformation/1-network.yaml \
      --parameters ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
      --region $AWS_REGION
fi

echo "⏳ Waiting for Network Stack to complete..."
aws cloudformation wait stack-create-complete --stack-name $NETWORK_STACK --region $AWS_REGION 2>/dev/null || \
aws cloudformation wait stack-update-complete --stack-name $NETWORK_STACK --region $AWS_REGION 2>/dev/null || true

echo "✅ Network Stack complete"

# 5. Deploy RDS Stack
echo ""
echo "5️⃣  Deploying RDS Stack..."

RDS_STACK="ibor-rds-$ENVIRONMENT"

if aws cloudformation describe-stacks --stack-name $RDS_STACK --region $AWS_REGION 2>/dev/null; then
    echo "ℹ️  Updating existing stack..."
    aws cloudformation update-stack \
      --stack-name $RDS_STACK \
      --template-body file://cloudformation/2-rds.yaml \
      --parameters file:///tmp/cf-params.json \
      --region $AWS_REGION
else
    echo "📦 Creating new stack..."
    aws cloudformation create-stack \
      --stack-name $RDS_STACK \
      --template-body file://cloudformation/2-rds.yaml \
      --parameters file:///tmp/cf-params.json \
      --region $AWS_REGION
fi

echo "⏳ Waiting for RDS Stack to complete..."
aws cloudformation wait stack-create-complete --stack-name $RDS_STACK --region $AWS_REGION 2>/dev/null || \
aws cloudformation wait stack-update-complete --stack-name $RDS_STACK --region $AWS_REGION 2>/dev/null || true

echo "✅ RDS Stack complete"

# 6. Deploy ECS Stack
echo ""
echo "6️⃣  Deploying ECS Stack..."

ECS_STACK="ibor-ecs-$ENVIRONMENT"

if aws cloudformation describe-stacks --stack-name $ECS_STACK --region $AWS_REGION 2>/dev/null; then
    echo "ℹ️  Updating existing stack..."
    aws cloudformation update-stack \
      --stack-name $ECS_STACK \
      --template-body file://cloudformation/3-ecs.yaml \
      --parameters file:///tmp/cf-params.json \
      --capabilities CAPABILITY_IAM \
      --region $AWS_REGION
else
    echo "📦 Creating new stack..."
    aws cloudformation create-stack \
      --stack-name $ECS_STACK \
      --template-body file://cloudformation/3-ecs.yaml \
      --parameters file:///tmp/cf-params.json \
      --capabilities CAPABILITY_IAM \
      --region $AWS_REGION
fi

echo "⏳ Waiting for ECS Stack to complete..."
aws cloudformation wait stack-create-complete --stack-name $ECS_STACK --region $AWS_REGION 2>/dev/null || \
aws cloudformation wait stack-update-complete --stack-name $ECS_STACK --region $AWS_REGION 2>/dev/null || true

echo "✅ ECS Stack complete"

# 7. Deploy Frontend Stack
echo ""
echo "7️⃣  Deploying Frontend Stack..."

ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name $ECS_STACK \
  --region $AWS_REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDnsName`].OutputValue' \
  --output text)

FRONTEND_STACK="ibor-frontend-$ENVIRONMENT"

if aws cloudformation describe-stacks --stack-name $FRONTEND_STACK --region $AWS_REGION 2>/dev/null; then
    echo "ℹ️  Updating existing stack..."
    aws cloudformation update-stack \
      --stack-name $FRONTEND_STACK \
      --template-body file://cloudformation/4-frontend.yaml \
      --parameters \
        ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
        ParameterKey=ApiEndpoint,ParameterValue=http://$ALB_DNS \
      --region $AWS_REGION
else
    echo "📦 Creating new stack..."
    aws cloudformation create-stack \
      --stack-name $FRONTEND_STACK \
      --template-body file://cloudformation/4-frontend.yaml \
      --parameters \
        ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
        ParameterKey=ApiEndpoint,ParameterValue=http://$ALB_DNS \
      --region $AWS_REGION
fi

echo "⏳ Waiting for Frontend Stack to complete..."
aws cloudformation wait stack-create-complete --stack-name $FRONTEND_STACK --region $AWS_REGION 2>/dev/null || \
aws cloudformation wait stack-update-complete --stack-name $FRONTEND_STACK --region $AWS_REGION 2>/dev/null || true

echo "✅ Frontend Stack complete"

# 8. Summary
echo ""
echo "✅ Deployment Complete!"
echo "=============================================="
echo ""
echo "📍 Access Points:"
echo "   ALB: http://$ALB_DNS"
echo "   API: http://$ALB_DNS/analyst/chat"
echo "   API Docs: http://$ALB_DNS/docs"
echo ""
echo "📊 Monitor:"
echo "   Logs: aws logs tail /ecs/ibor-$ENVIRONMENT --follow"
echo "   Stacks: aws cloudformation list-stacks --region $AWS_REGION"
echo ""
echo "🚀 Next Steps:"
echo "   1. Build and push Docker images"
echo "   2. Initialize database schema"
echo "   3. Build and deploy React frontend"
echo ""
echo "📖 For detailed instructions, see: internal/DEPLOYMENT_AWS_CLOUDFORMATION.md"
echo ""

rm -f /tmp/cf-params.json
