#!/bin/bash

# Google Analytics Pipeline Deployment Script
set -e

echo "🚀 Starting Google Analytics Pipeline Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "Prerequisites check passed!"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan the deployment
    terraform plan -out=tfplan
    
    # Apply the plan
    terraform apply tfplan
    
    # Get outputs
    S3_BUCKET=$(terraform output -raw s3_bucket_name)
    LAMBDA_ROLE_ARN=$(terraform output -raw lambda_role_arn)
    GLUE_ROLE_ARN=$(terraform output -raw glue_role_arn)
    
    cd ..
    
    # Export variables for later use
    export S3_BUCKET
    export LAMBDA_ROLE_ARN
    export GLUE_ROLE_ARN
    
    print_status "Infrastructure deployed successfully!"
    print_status "S3 Bucket: $S3_BUCKET"
    print_status "Lambda Role ARN: $LAMBDA_ROLE_ARN"
    print_status "Glue Role ARN: $GLUE_ROLE_ARN"
}

# Deploy Lambda function
deploy_lambda() {
    print_status "Deploying Lambda function..."
    
    cd lambda
    
    # Install dependencies
    pip install requests boto3 -t .
    
    # Create deployment package
    zip -r ga_ingest.zip .
    
    # Deploy Lambda function
    aws lambda create-function \
        --function-name ga-ingest-lambda \
        --runtime python3.9 \
        --role "$LAMBDA_ROLE_ARN" \
        --handler ga_ingest.lambda_handler \
        --zip-file fileb://ga_ingest.zip \
        --timeout 300 \
        --environment Variables="S3_BUCKET=$S3_BUCKET" \
        --description "Google Analytics data ingestion function" || {
        print_warning "Lambda function might already exist. Updating..."
        aws lambda update-function-code \
            --function-name ga-ingest-lambda \
            --zip-file fileb://ga_ingest.zip
    }
    
    cd ..
    
    print_status "Lambda function deployed successfully!"
}

# Upload Glue jobs to S3
upload_glue_jobs() {
    print_status "Uploading Glue jobs to S3..."
    
    aws s3 cp glue_jobs/ga_landing_to_raw.py "s3://$S3_BUCKET/glue_jobs/"
    aws s3 cp glue_jobs/ga_to_redshift.py "s3://$S3_BUCKET/glue_jobs/"
    
    print_status "Glue jobs uploaded successfully!"
}

# Create Glue jobs
create_glue_jobs() {
    print_status "Creating Glue jobs..."
    
    # Create landing to raw job
    aws glue create-job \
        --name ga_landing_to_raw_job \
        --role "$GLUE_ROLE_ARN" \
        --command Name=glueetl,ScriptLocation="s3://$S3_BUCKET/glue_jobs/ga_landing_to_raw.py" \
        --default-arguments '{"--job-language":"python","--job-bookmark-option":"job-bookmark-enable"}' \
        --description "Process GA data from landing to raw zone" || {
        print_warning "Glue job ga_landing_to_raw_job might already exist."
    }
    
    # Create Redshift load job
    aws glue create-job \
        --name ga_to_redshift_job \
        --role "$GLUE_ROLE_ARN" \
        --command Name=glueetl,ScriptLocation="s3://$S3_BUCKET/glue_jobs/ga_to_redshift.py" \
        --default-arguments '{"--job-language":"python","--job-bookmark-option":"job-bookmark-enable"}' \
        --description "Load GA data to Redshift" || {
        print_warning "Glue job ga_to_redshift_job might already exist."
    }
    
    print_status "Glue jobs created successfully!"
}

# Test the pipeline
test_pipeline() {
    print_status "Testing the pipeline..."
    
    # Test Lambda function
    print_status "Testing Lambda function..."
    aws lambda invoke \
        --function-name ga-ingest-lambda \
        --payload '{}' \
        response.json
    
    if [ -f response.json ]; then
        print_status "Lambda function test completed. Check response.json for details."
        cat response.json
        rm response.json
    fi
    
    # Check S3 for ingested data
    print_status "Checking S3 for ingested data..."
    aws s3 ls "s3://$S3_BUCKET/landing/ga_events/" || {
        print_warning "No data found in landing zone yet. This is normal for first run."
    }
    
    print_status "Pipeline test completed!"
}

# Main deployment function
main() {
    echo "=========================================="
    echo "Google Analytics Pipeline Deployment"
    echo "=========================================="
    
    check_prerequisites
    deploy_infrastructure
    deploy_lambda
    upload_glue_jobs
    create_glue_jobs
    test_pipeline
    
    echo "=========================================="
    print_status "Deployment completed successfully!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Update your Google Analytics View ID in lambda/ga_ingest.py"
    echo "2. Configure Redshift connection in Glue console (if using internal tables)"
    echo "3. Set up Step Functions for orchestration (optional)"
    echo "4. Configure DBT for data transformation (optional)"
    echo ""
    echo "For detailed instructions, see README.md"
}

# Run main function
main "$@" 