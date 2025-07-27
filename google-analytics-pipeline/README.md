# Google Analytics 4 Data Pipeline

A complete data pipeline that ingests Google Analytics 4 data, processes it using AWS Glue, and loads it into Amazon Redshift with both Spectrum and internal table support.

## Architecture Overview

```
[Google Analytics 4 API] → [Lambda] → [S3 Landing] → [Glue Crawler] → [Glue Job] → [S3 Raw] → [Glue Crawler] → [Glue Job] → [Redshift]
```

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Google Analytics 4 API Key** (already provided: `_`)
3. **Google Analytics 4 Property ID** (you need to provide this)
4. **Amazon Redshift Cluster** (if using internal tables)
5. **AWS CLI** configured with appropriate credentials

## Step-by-Step Deployment

### Step 1: Deploy Infrastructure with Terraform

1. **Navigate to terraform directory:**
   ```bash
   cd google-analytics-pipeline/terraform
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Review the plan:**
   ```bash
   terraform plan
   ```

4. **Apply the infrastructure:**
   ```bash
   terraform apply
   ```

5. **Note the outputs** (you'll need these for later steps):
   - S3 bucket name
   - Lambda role ARN
   - Glue role ARN

### Step 2: Configure Google Analytics 4 API

1. **Update the Lambda function** (`lambda/ga_ingest.py`):
   - Replace `YOUR_PROPERTY_ID` with your actual Google Analytics 4 Property ID
   - The API key is already configured

2. **Get your Google Analytics 4 Property ID:**
   - Go to Google Analytics Admin
   - Navigate to Property Settings
   - Copy the Property ID (format: `123456789`)

### Step 3: Deploy Lambda Function

1. **Create deployment package:**
   ```bash
   cd google-analytics-pipeline/lambda
   pip install requests boto3 -t .
   zip -r ga_ingest.zip .
   ```

2. **Deploy Lambda function:**
   ```bash
   aws lambda create-function \
     --function-name ga-ingest-lambda \
     --runtime python3.9 \
     --role <LAMBDA_ROLE_ARN> \
     --handler ga_ingest.lambda_handler \
     --zip-file fileb://ga_ingest.zip \
     --timeout 300 \
     --environment Variables='{S3_BUCKET=<S3_BUCKET_NAME>}'
   ```

### Step 4: Create Glue Jobs

1. **Create the landing to raw job:**
   ```bash
   aws glue create-job \
     --name ga_landing_to_raw_job \
     --role <GLUE_ROLE_ARN> \
     --command Name=glueetl,ScriptLocation=s3://<S3_BUCKET_NAME>/glue_jobs/ga_landing_to_raw.py \
     --default-arguments '{"--job-language":"python","--job-bookmark-option":"job-bookmark-enable"}'
   ```

2. **Create the Redshift load job:**
   ```bash
   aws glue create-job \
     --name ga_to_redshift_job \
     --role <GLUE_ROLE_ARN> \
     --command Name=glueetl,ScriptLocation=s3://<S3_BUCKET_NAME>/glue_jobs/ga_to_redshift.py \
     --default-arguments '{"--job-language":"python","--job-bookmark-option":"job-bookmark-enable"}'
   ```

3. **Upload Glue job scripts to S3:**
   ```bash
   aws s3 cp glue_jobs/ga_landing_to_raw.py s3://<S3_BUCKET_NAME>/glue_jobs/
   aws s3 cp glue_jobs/ga_to_redshift.py s3://<S3_BUCKET_NAME>/glue_jobs/
   ```

### Step 5: Configure Redshift (if using internal tables)

1. **Create Redshift connection in Glue:**
   - Go to AWS Glue Console
   - Navigate to Connections
   - Create a new JDBC connection named `redshift-connection`
   - Configure with your Redshift cluster details

2. **Create the target table in Redshift:**
   ```sql
   CREATE SCHEMA IF NOT EXISTS analytics;
   
   CREATE TABLE analytics.ga4_events_cleaned (
     event_date DATE,
     page_path VARCHAR(500),
     traffic_source VARCHAR(100),
     traffic_medium VARCHAR(100),
     sessions INTEGER,
     total_users INTEGER,
     screen_page_views INTEGER,
     event_count INTEGER,
     processed_at TIMESTAMP
   );
   ```

### Step 6: Deploy Step Functions (Optional)

1. **Create Step Functions state machine:**
   ```bash
   aws stepfunctions create-state-machine \
     --name ga-pipeline \
     --definition file://step_functions_pipeline.json \
     --role-arn <STEP_FUNCTIONS_ROLE_ARN>
   ```

### Step 7: Test the Pipeline

1. **Test Lambda function manually:**
   ```bash
   aws lambda invoke \
     --function-name ga-ingest-lambda \
     --payload '{}' \
     response.json
   ```

2. **Check S3 for ingested data:**
   ```bash
   aws s3 ls s3://<S3_BUCKET_NAME>/landing/ga_events/
   ```

3. **Run crawlers manually:**
   ```bash
   aws glue start-crawler --name ga_events_landing_crawler
   aws glue start-crawler --name ga_events_raw_crawler
   ```

4. **Run Glue jobs manually:**
   ```bash
   aws glue start-job-run --job-name ga_landing_to_raw_job
   aws glue start-job-run --job-name ga_to_redshift_job
   ```

### Step 8: Set up DBT (Optional)

1. **Install DBT:**
   ```bash
   pip install dbt-core dbt-redshift
   ```

2. **Initialize DBT project:**
   ```bash
   cd google-analytics-pipeline/dbt_models
   dbt init ga_analytics
   ```

3. **Configure DBT profile** (`~/.dbt/profiles.yml`):
   ```yaml
   ga_analytics:
     target: dev
     outputs:
       dev:
         type: redshift
         host: <REDSHIFT_HOST>
         user: <REDSHIFT_USER>
         password: <REDSHIFT_PASSWORD>
         port: 5439
         dbname: <REDSHIFT_DATABASE>
         schema: analytics
         threads: 4
   ```

4. **Run DBT models:**
   ```bash
   dbt run
   ```

## Monitoring and Troubleshooting

### CloudWatch Logs
- Lambda logs: `/aws/lambda/ga-ingest-lambda`
- Glue job logs: Check Glue console for job run logs

### Common Issues
1. **API Key issues**: Verify Google Analytics 4 API key and Property ID
2. **S3 permissions**: Ensure Lambda and Glue roles have proper S3 permissions
3. **Redshift connection**: Verify JDBC connection details in Glue

## Data Flow

1. **Landing Zone**: Raw JSON from Google Analytics 4 API
2. **Raw Zone**: Processed and cleaned data in Parquet format
3. **Redshift**: Final curated data for reporting

## Query Examples

### Redshift Spectrum (querying S3 data)
```sql
SELECT * FROM spectrum_analytics.ga_events_raw 
WHERE event_date = '2024-01-01';
```

### Redshift Internal Table
```sql
SELECT 
  event_date,
  SUM(sessions) as total_sessions,
  SUM(total_users) as total_users,
  SUM(screen_page_views) as total_page_views
FROM analytics.ga4_events_cleaned 
GROUP BY event_date
ORDER BY event_date DESC;
```

## GA4 Data Structure

The pipeline processes the following GA4 metrics and dimensions:

**Dimensions:**
- `date`: Event date
- `pagePath`: Page path visited
- `source`: Traffic source
- `medium`: Traffic medium

**Metrics:**
- `sessions`: Number of sessions
- `totalUsers`: Number of total users
- `screenPageViews`: Number of screen page views
- `eventCount`: Number of events

## Cost Optimization

- Use S3 lifecycle policies to move old data to cheaper storage
- Schedule crawlers to run less frequently
- Use appropriate Glue worker types based on data volume

## Security Notes

- Store API keys in AWS Secrets Manager (not in code)
- Use IAM roles with minimal required permissions
- Enable S3 bucket encryption
- Use VPC endpoints for private communication

## Next Steps

1. Set up monitoring and alerting
2. Implement data quality checks
3. Add more Google Analytics 4 dimensions and metrics
4. Create automated testing
5. Set up CI/CD pipeline 