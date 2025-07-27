import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
from pyspark.sql.types import *

# Initialize Glue context
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Read from landing zone
landing_df = glueContext.create_dynamic_frame.from_catalog(
    database="analytics_landing",
    table_name="ga_events_landing"
)

# Convert to Spark DataFrame for easier processing
spark_df = landing_df.toDF()

# Extract and flatten the GA4 data structure
def process_ga4_data(df):
    """Process Google Analytics 4 data and extract relevant fields"""
    
    # GA4 API returns a different structure than Universal Analytics
    # The data is in the 'rows' field with dimensionValues and metricValues
    
    if df.count() > 0:
        # Get the first row (assuming single report)
        first_row = df.first()
        
        if first_row and 'rows' in first_row and first_row.rows:
            # Create a new DataFrame with exploded rows
            rows_data = []
            for row in first_row.rows:
                # Extract dimension values
                dimensions = row.get('dimensionValues', [])
                metrics = row.get('metricValues', [])
                
                row_dict = {
                    'date': dimensions[0].get('value') if len(dimensions) > 0 else None,
                    'page_path': dimensions[1].get('value') if len(dimensions) > 1 else None,
                    'source': dimensions[2].get('value') if len(dimensions) > 2 else None,
                    'medium': dimensions[3].get('value') if len(dimensions) > 3 else None,
                    'sessions': metrics[0].get('value') if len(metrics) > 0 else 0,
                    'total_users': metrics[1].get('value') if len(metrics) > 1 else 0,
                    'screen_page_views': metrics[2].get('value') if len(metrics) > 2 else 0,
                    'event_count': metrics[3].get('value') if len(metrics) > 3 else 0,
                    'processed_at': current_timestamp()
                }
                rows_data.append(row_dict)
            
            return spark.createDataFrame(rows_data)
    
    # Return empty DataFrame if no data
    return spark.createDataFrame([], StructType([
        StructField("date", StringType(), True),
        StructField("page_path", StringType(), True),
        StructField("source", StringType(), True),
        StructField("medium", StringType(), True),
        StructField("sessions", StringType(), True),
        StructField("total_users", StringType(), True),
        StructField("screen_page_views", StringType(), True),
        StructField("event_count", StringType(), True),
        StructField("processed_at", TimestampType(), True)
    ]))

# Process the data
processed_df = process_ga4_data(spark_df)

# Convert back to DynamicFrame
processed_dynamic_frame = DynamicFrame.fromDF(processed_df, glueContext, "processed_ga4_data")

# Write to raw zone
glueContext.write_dynamic_frame.from_options(
    frame=processed_dynamic_frame,
    connection_type="s3",
    connection_options={
        "path": "s3://my-ga-analytics-data/raw/ga_events/",
        "partitionKeys": ["date"]
    },
    format="parquet"
)

job.commit() 