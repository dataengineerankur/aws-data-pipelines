# Google Analytics 4 Pipeline Configuration

# Google Analytics 4 API Configuration
GA_API_KEY = ''  # Your API key
GA4_PROPERTY_ID = 'YOUR_PROPERTY_ID'  # Replace with your GA4 property ID (format: 123456789)

# AWS Configuration
AWS_REGION = 'us-east-1'

# S3 Configuration
S3_BUCKET_PREFIX = 'my-ga-analytics-data'
S3_LANDING_PATH = 'landing/ga_events/'
S3_RAW_PATH = 'raw/ga_events/'
S3_TMP_PATH = 'tmp/'

# Glue Configuration
GLUE_DATABASE_LANDING = 'analytics_landing'
GLUE_DATABASE_RAW = 'analytics_raw'
GLUE_TABLE_LANDING = 'ga_events_landing'
GLUE_TABLE_RAW = 'ga_events_raw'

# Redshift Configuration
REDSHIFT_SCHEMA = 'analytics'
REDSHIFT_TABLE = 'ga4_events_cleaned'
REDSHIFT_CONNECTION = 'redshift-connection'

# Lambda Configuration
LAMBDA_FUNCTION_NAME = 'ga-ingest-lambda'
LAMBDA_TIMEOUT = 300
LAMBDA_MEMORY = 512

# Glue Job Configuration
GLUE_JOB_LANDING_TO_RAW = 'ga_landing_to_raw_job'
GLUE_JOB_TO_REDSHIFT = 'ga_to_redshift_job'
GLUE_WORKER_TYPE = 'G.1X'
GLUE_NUM_WORKERS = 2

# Step Functions Configuration
STEP_FUNCTIONS_STATE_MACHINE = 'ga-pipeline'

# Data Processing Configuration
DATA_RETENTION_DAYS = 90
PROCESSING_SCHEDULE = 'cron(0 */6 * * ? *)'  # Every 6 hours

# GA4 API Configuration
GA4_API_ENDPOINT = 'https://analyticsdata.googleapis.com/v1beta'
GA4_DIMENSIONS = ['date', 'pagePath', 'source', 'medium']
GA4_METRICS = ['sessions', 'totalUsers', 'screenPageViews', 'eventCount']
GA4_LIMIT = 10000 