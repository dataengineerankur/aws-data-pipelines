import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *

# Initialize Glue context
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Read from raw zone
raw_df = glueContext.create_dynamic_frame.from_catalog(
    database="analytics_raw",
    table_name="ga_events_raw"
)

# Convert to Spark DataFrame for processing
spark_df = raw_df.toDF()

# Clean and transform data for Redshift
def clean_ga4_data(df):
    """Clean and prepare GA4 data for Redshift"""
    
    cleaned_df = df.select(
        col("date").cast("date").alias("event_date"),
        col("page_path").alias("page_path"),
        col("source").alias("traffic_source"),
        col("medium").alias("traffic_medium"),
        col("sessions").cast("integer").alias("sessions"),
        col("total_users").cast("integer").alias("total_users"),
        col("screen_page_views").cast("integer").alias("screen_page_views"),
        col("event_count").cast("integer").alias("event_count"),
        col("processed_at").alias("processed_at")
    ).filter(
        col("event_date").isNotNull() &
        col("page_path").isNotNull()
    )
    
    return cleaned_df

# Clean the data
cleaned_df = clean_ga4_data(spark_df)

# Convert back to DynamicFrame
cleaned_dynamic_frame = DynamicFrame.fromDF(cleaned_df, glueContext, "cleaned_ga4_data")

# Write to Redshift
glueContext.write_dynamic_frame.from_jdbc_conf(
    frame=cleaned_dynamic_frame,
    catalog_connection="redshift-connection",  # Configure this in Glue connections
    connection_options={
        "dbtable": "analytics.ga4_events_cleaned",
        "database": "analytics",
        "preactions": "TRUNCATE TABLE analytics.ga4_events_cleaned;"  # Optional: truncate before insert
    },
    redshift_tmp_dir="s3://my-ga-analytics-data/tmp/"
)

job.commit() 