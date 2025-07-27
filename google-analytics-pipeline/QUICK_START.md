# Quick Start Guide - Google Analytics 4 Pipeline

## 🚀 Deploy in 5 Minutes

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform installed
- Google Analytics 4 Property ID ready

### Step 1: Update Configuration
Edit `lambda/ga_ingest.py` and replace `YOUR_PROPERTY_ID` with your actual Google Analytics 4 Property ID.

### Step 2: Run Deployment Script
```bash
./deploy.sh
```

This script will:
- ✅ Deploy all AWS infrastructure (S3, IAM roles, Glue databases, crawlers)
- ✅ Deploy Lambda function for data ingestion
- ✅ Upload and create Glue jobs
- ✅ Test the pipeline

### Step 3: Verify Deployment
Check the outputs from the deployment script and verify:
- S3 bucket created
- Lambda function deployed
- Glue jobs created
- Crawlers configured

### Step 4: Manual Testing
```bash
# Test Lambda function
aws lambda invoke --function-name ga-ingest-lambda --payload '{}' response.json

# Check S3 for data
aws s3 ls s3://<YOUR_BUCKET_NAME>/landing/ga_events/

# Run crawlers
aws glue start-crawler --name ga_events_landing_crawler
aws glue start-crawler --name ga_events_raw_crawler

# Run Glue jobs
aws glue start-job-run --job-name ga_landing_to_raw_job
aws glue start-job-run --job-name ga_to_redshift_job
```

## 📊 Data Flow
1. **Lambda** fetches GA4 data → **S3 Landing**
2. **Crawler** creates table → **Glue Catalog**
3. **Glue Job** processes data → **S3 Raw**
4. **Crawler** creates table → **Glue Catalog**
5. **Glue Job** loads to **Redshift**

## 🔧 Configuration
- **API Key**: Already configured (`_`)
- **Property ID**: Update in `lambda/ga_ingest.py`
- **Schedule**: Every 6 hours (configurable in Terraform)

## 📈 GA4 Data Structure
The pipeline processes these GA4 metrics and dimensions:

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

## 📈 Next Steps
1. Set up Redshift connection in Glue console
2. Configure Step Functions for orchestration
3. Set up DBT for data transformation
4. Add monitoring and alerting

## 🆘 Troubleshooting
- **Lambda errors**: Check CloudWatch logs
- **Glue job failures**: Check job run logs in Glue console
- **S3 permissions**: Verify IAM roles have proper access
- **API issues**: Verify Google Analytics 4 Property ID and API key

## 📚 Full Documentation
See `README.md` for detailed instructions and advanced configuration options. 