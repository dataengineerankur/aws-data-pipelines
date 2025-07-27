# Google Analytics 4 Pipeline - Data Architecture & Flow

## 📊 Complete Data Flow Architecture

### **Phase 1: Data Ingestion Flow**
```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    GOOGLE ANALYTICS 4 DATA PIPELINE - COMPLETE FLOW                          │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Google        │    │   AWS Lambda    │    │   Amazon S3     │    │   AWS Glue      │    │   Glue Catalog  │
│   Analytics 4   │───▶│   Function      │───▶│   Landing Zone  │───▶│   Crawler 1     │───▶│   Database      │
│   Data API v1   │    │   (ga_ingest.py)│    │   (Raw JSON)    │    │   (Metadata)    │    │   (analytics_  │
│                 │    │                 │    │                 │    │                 │    │    landing)     │
│   Dimensions:   │    │   - Fetches GA4 │    │   File Format:  │    │   - Scans S3    │    │   Table:        │
│   - date        │    │     data        │    │   ga4_events_   │    │     landing     │    │   ga_events_    │
│   - pagePath    │    │   - Stores JSON │    │   YYYY-MM-DD_   │    │     zone        │    │   landing       │
│   - source      │    │     to S3       │    │   HHMMSS.json   │    │   - Creates     │    │                 │
│   - medium      │    │   - Logs to     │    │                 │    │     table       │    │   Schema:       │
│                 │    │     CloudWatch  │    │   Data: Raw     │    │     schema      │    │   - rows        │
│   Metrics:      │    │                 │    │   GA4 API       │    │   - Updates     │    │   - dimension   │
│   - sessions    │    │   Schedule:     │    │   response      │    │     metadata    │    │     Values      │
│   - totalUsers  │    │   Every 6 hours │    │   (unprocessed) │    │                 │    │   - metric      │
│   - screenPage  │    │                 │    │                 │    │   Schedule:     │    │     Values      │
│     Views       │    │   Error:        │    │   Size: ~1-5MB  │    │   Every 6 hours │    │   - processed_  │
│   - eventCount  │    │   CloudWatch    │    │   per file      │    │                 │    │     at          │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                        │
                                ▼                        ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │   CloudWatch    │    │   AWS Step      │    │   AWS Glue      │
                       │   Logs          │    │   Functions     │    │   Job 1         │
                       │   (Monitoring)  │    │   (Orchestration)│    │   (ETL Process) │
                       │                 │    │                 │    │                 │
                       │   - Lambda      │    │   - Triggers    │    │   - Reads from  │
                       │     execution   │    │     Lambda      │    │     landing     │
                       │     logs        │    │   - Starts      │    │     table       │
                       │   - Error       │    │     crawlers    │    │   - Transforms  │
                       │     tracking    │    │   - Waits for   │    │     JSON to     │
                       │   - Performance │    │     completion  │    │     structured  │
                       │     metrics     │    │   - Triggers    │    │     data        │
                       │                 │    │     Glue jobs   │    │   - Writes to   │
                       │   Retention:    │    │   - Handles     │    │     raw zone    │
                       │   30 days       │    │     errors      │    │   - Parquet     │
                       └─────────────────┘    └─────────────────┘    │     format      │
                                                                     │                 │
                                                                     │   Input:        │
                                                                     │   - JSON files  │
                                                                     │   - GA4 API     │
                                                                     │     response    │
                                                                     │                 │
                                                                     │   Output:       │
                                                                     │   - Structured  │
                                                                     │     Parquet     │
                                                                     │   - Partitioned │
                                                                     │     by date     │
                                                                     └─────────────────┘
                                                                              │
                                                                              ▼
                                                                     ┌─────────────────┐
                                                                     │   Amazon S3     │
                                                                     │   Raw Zone      │
                                                                     │   (Processed)   │
                                                                     │                 │
                                                                     │   File Format:  │
                                                                     │   ga_events_    │
                                                                     │   raw/date=     │
                                                                     │   YYYY-MM-DD/   │
                                                                     │   part-*.parquet│
                                                                     │                 │
                                                                     │   Schema:       │
                                                                     │   - event_date  │
                                                                     │   - page_path   │
                                                                     │   - traffic_    │
                                                                     │     source      │
                                                                     │   - traffic_    │
                                                                     │     medium      │
                                                                     │   - sessions    │
                                                                     │   - total_users │
                                                                     │   - screen_page_│
                                                                     │     views       │
                                                                     │   - event_count │
                                                                     │   - processed_  │
                                                                     │     at          │
                                                                     └─────────────────┘
                                                                              │
                                                                              ▼
                                                                     ┌─────────────────┐
                                                                     │   AWS Glue      │
                                                                     │   Crawler 2     │
                                                                     │   (Metadata)    │
                                                                     │                 │
                                                                     │   - Scans S3    │
                                                                     │     raw zone    │
                                                                     │   - Creates     │
                                                                     │     table       │
                                                                     │     schema      │
                                                                     │   - Updates     │
                                                                     │     metadata    │
                                                                     │                 │
                                                                     │   Schedule:     │
                                                                     │   Every 6 hours │
                                                                     └─────────────────┘
                                                                              │
                                                                              ▼
                                                                     ┌─────────────────┐
                                                                     │   Glue Catalog  │
                                                                     │   Database      │
                                                                     │   (analytics_   │
                                                                     │    raw)         │
                                                                     │                 │
                                                                     │   Table:        │
                                                                     │   ga_events_raw │
                                                                     │                 │
                                                                     │   Schema:       │
                                                                     │   - event_date  │
                                                                     │   - page_path   │
                                                                     │   - traffic_    │
                                                                     │     source      │
                                                                     │   - traffic_    │
                                                                     │     medium      │
                                                                     │   - sessions    │
                                                                     │   - total_users │
                                                                     │   - screen_page_│
                                                                     │     views       │
                                                                     │   - event_count │
                                                                     │   - processed_  │
                                                                     │     at          │
                                                                     └─────────────────┘
                                                                              │
                                                                              ▼
                                                                     ┌─────────────────┐
                                                                     │   AWS Glue      │
                                                                     │   Job 2         │
                                                                     │   (Redshift     │
                                                                     │    Load)        │
                                                                     │                 │
                                                                     │   - Reads from  │
                                                                     │     raw table   │
                                                                     │   - Cleans data │
                                                                     │   - Loads to    │
                                                                     │     Redshift    │
                                                                     │   - Uses JDBC   │
                                                                     │     connection  │
                                                                     │                 │
                                                                     │   Input:        │
                                                                     │   - Parquet     │
                                                                     │     files       │
                                                                     │   - Structured  │
                                                                     │     data        │
                                                                     │                 │
                                                                     │   Output:       │
                                                                     │   - Redshift    │
                                                                     │     table       │
                                                                     │   - Cleaned     │
                                                                     │     data        │
                                                                     └─────────────────┘
                                                                              │
                                                                              ▼
                                                                     ┌─────────────────┐
                                                                     │   Amazon        │
                                                                     │   Redshift      │
                                                                     │   (Internal     │
                                                                     │    Tables)      │
                                                                     │                 │
                                                                     │   Database:     │
                                                                     │   analytics     │
                                                                     │                 │
                                                                     │   Table:        │
                                                                     │   ga4_events_   │
                                                                     │   cleaned       │
                                                                     │                 │
                                                                     │   Schema:       │
                                                                     │   - event_date  │
                                                                     │   - page_path   │
                                                                     │   - traffic_    │
                                                                     │     source      │
                                                                     │   - traffic_    │
                                                                     │     medium      │
                                                                     │   - sessions    │
                                                                     │   - total_users │
                                                                     │   - screen_page_│
                                                                     │     views       │
                                                                     │   - event_count │
                                                                     │   - processed_  │
                                                                     │     at          │
                                                                     └─────────────────┘
                                                                              │
                                                                              ▼
                                                                     ┌─────────────────┐
                                                                     │   DBT Models    │
                                                                     │   (Transform)   │
                                                                     │                 │
                                                                     │   - Reads from  │
                                                                     │     Redshift    │
                                                                     │   - Applies     │
                                                                     │     business    │
                                                                     │     logic       │
                                                                     │   - Creates     │
                                                                     │     calculated  │
                                                                     │     fields      │
                                                                     │   - Writes back │
                                                                     │     to Redshift │
                                                                     │                 │
                                                                     │   Output:       │
                                                                     │   - Enhanced    │
                                                                     │     analytics   │
                                                                     │   - KPIs        │
                                                                     │   - Metrics     │
                                                                     └─────────────────┘
```

### **Phase 2: Data Querying & Analytics Flow**

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    DATA QUERYING & ANALYTICS FLOW                                            │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Amazon S3     │    │   Redshift      │    │   Redshift      │    │   Business      │    │   Analytics     │
│   Raw Zone      │───▶│   Spectrum      │───▶│   Internal      │───▶│   Intelligence  │───▶│   Dashboard     │
│   (Parquet)     │    │   (External     │    │   Tables        │    │   (DBT Models)  │    │   (Tableau/     │
│                 │    │    Tables)      │    │   (Cleaned)     │    │                 │    │    PowerBI)     │
│   Use Cases:    │    │                 │    │                 │    │                 │    │                 │
│   - Ad-hoc      │    │   - Query S3    │    │   - Fast        │    │   - Calculated  │    │   - Real-time   │
│     queries     │    │     data        │    │     queries     │    │     metrics     │    │     dashboards  │
│   - Data        │    │   - No data     │    │   - Aggregated  │    │   - Business    │    │   - KPIs        │
│     exploration │    │     movement    │    │     views       │    │     rules        │    │   - Reports     │
│   - Cost-       │    │   - Pay per     │    │   - Optimized   │    │   - Data        │    │   - Alerts      │
│     effective   │    │     query       │    │     for speed   │    │     quality      │    │                 │
│   - Large       │    │   - Unlimited   │    │   - Indexed     │    │   - Transform-  │    │   Examples:     │
│     datasets    │    │     scale       │    │     columns     │    │     ations      │    │   - User        │
│                 │    │                 │    │                 │    │                 │    │     behavior     │
│   Query         │    │   Query         │    │   Query         │    │   Output:       │    │   - Conversion   │
│   Example:      │    │   Example:      │    │   Example:      │    │   - pages_per_  │    │     funnels      │
│   SELECT *      │    │   SELECT        │    │   SELECT        │    │     session     │    │   - Traffic      │
│   FROM          │    │     date,       │    │     event_date, │    │   - sessions_   │    │     sources      │
│   spectrum_     │    │     page_path,  │    │     page_path,  │    │     per_user    │    │   - Page        │
│   analytics.    │    │     sessions    │    │     sessions,   │    │   - events_per_ │    │     performance  │
│   ga_events_raw │    │   FROM          │    │     total_users │    │     session     │    │   - Revenue      │
│   WHERE         │    │   spectrum_     │    │   FROM          │    │                 │    │     tracking     │
│   date >=       │    │   analytics.    │    │   analytics.    │    │   Table:        │    │                 │
│   '2024-01-01'  │    │   ga_events_raw │    │   ga4_events_   │    │   ga4_events_   │    │   Refresh:      │
│                 │    │   WHERE         │    │   cleaned       │    │   enhanced      │    │   Every 6 hours │
└─────────────────┘    │   date >=       │    │   WHERE         │    │                 │    │                 │
                       │   '2024-01-01'  │    │   event_date >= │    │   Schema:       │    │   Data Sources: │
                       └─────────────────┘    │   '2024-01-01'  │    │   - All base    │    │   - Redshift    │
                                              └─────────────────┘    │     fields       │    │     internal     │
                                                                     │   - pages_per_  │    │     tables       │
                                                                     │     session     │    │   - DBT models   │
                                                                     │   - sessions_   │    │   - Real-time    │
                                                                     │     per_user    │    │     updates      │
                                                                     │   - events_per_ │    │                 │
                                                                     │     session     │    │   Integration:  │
                                                                     │   - dbt_updated_│    │   - REST APIs    │
                                                                     │     at          │    │   - JDBC/ODBC    │
                                                                     └─────────────────┘    │   - Direct       │
                                                                                            │     queries      │
                                                                                            └─────────────────┘
```

## 🎨 **Colorful Visual Architecture**

### **Data Flow Color Coding:**
- 🔵 **Blue**: Data Sources & External Systems
- 🟢 **Green**: Data Processing & Transformation
- 🟡 **Yellow**: Data Storage & Persistence
- 🟠 **Orange**: Analytics & Business Intelligence
- 🔴 **Red**: Monitoring & Error Handling
- 🟣 **Purple**: Orchestration & Workflow

### **Detailed Component Breakdown:**

#### **1. Data Ingestion Layer (🔵)**
```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    🔵 DATA INGESTION LAYER                                                   │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   🔵 Google     │    │   🟢 AWS Lambda │    │   🟡 Amazon S3  │    │   🟢 CloudWatch │
│   Analytics 4   │───▶│   Function      │───▶│   Landing Zone  │───▶│   Logs          │
│   Data API v1   │    │                 │    │                 │    │                 │
│                 │    │   📊 Input:     │    │   📁 Format:    │    │   📈 Monitor:   │
│   🔑 API Key:   │    │   - GA4 API     │    │   - JSON        │    │   - Lambda      │
│   _02jt4WnSuuaQc│    │   - Property ID │    │   - Raw data    │    │     execution   │
│   Y0BUCDiA      │    │   - Date range  │    │   - Unprocessed │    │   - Errors      │
│                 │    │                 │    │                 │    │   - Performance │
│   🆔 Property   │    │   📤 Output:    │    │   📊 Size:      │    │   📅 Retention: │
│   ID: 312890004 │    │   - JSON file   │    │   1-5MB/file    │    │   30 days       │
│                 │    │   - S3 upload   │    │   - Timestamped │    │                 │
│   ⏰ Schedule:   │    │   - Logs       │    │   - Partitioned │    │   🔍 Alerts:    │
│   Every 6 hours │    │                 │    │                 │    │   - Failures    │
│                 │    │   ⚡ Runtime:   │    │   🗂️ Structure: │    │   - Timeouts    │
│   📊 Metrics:   │    │   300 seconds  │    │   ga4_events_   │    │   - Memory      │
│   - sessions    │    │   💾 Memory:    │    │   YYYY-MM-DD_   │    │                 │
│   - totalUsers  │    │   128 MB       │    │   HHMMSS.json   │    │   📊 Metrics:   │
│   - screenPage  │    │                 │    │                 │    │   - Duration    │
│     Views       │    │   🔧 Handler:   │    │   🔄 Lifecycle: │    │   - Invocations │
│   - eventCount  │    │   ga_ingest.   │    │   - Versioning  │    │   - Errors      │
│                 │    │   lambda_      │    │   - Encryption  │    │   - Throttles   │
│   📏 Dimensions:│    │   handler      │    │   - Backup      │    │                 │
│   - date        │    │                 │    │                 │    │   📋 Logs:      │
│   - pagePath    │    │   🛡️ Security: │    │   🔐 Access:    │    │   - Request ID  │
│   - source      │    │   - IAM role   │    │   - IAM roles   │    │   - Timestamp   │
│   - medium      │    │   - VPC        │    │   - Bucket      │    │   - Response    │
└─────────────────┘    │   - Encryption │    │     policies    │    │   - Errors      │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### **2. Data Processing Layer (🟢)**
```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    🟢 DATA PROCESSING LAYER                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   🟡 S3 Landing │    │   🟢 Glue       │    │   🟡 S3 Raw     │    │   🟢 Glue       │
│   Zone          │───▶│   Crawler 1     │───▶│   Zone          │───▶│   Job 1         │
│   (Raw JSON)    │    │   (Metadata)    │    │   (Parquet)     │    │   (ETL)         │
│                 │    │                 │    │                 │    │                 │
│   📁 Input:     │    │   🔍 Scans:     │    │   📊 Format:    │    │   🔄 Process:   │
│   - JSON files  │    │   - S3 landing  │    │   - Parquet     │    │   - JSON →      │
│   - GA4 API     │    │     zone        │    │   - Structured  │    │     Structured  │
│     response    │    │   - File        │    │   - Optimized   │    │   - Clean data  │
│                 │    │     patterns    │    │   - Compressed  │    │   - Transform   │
│   📊 Schema:    │    │   - Schema      │    │   - Partitioned │    │   - Validate    │
│   - rows        │    │     inference   │    │                 │    │                 │
│   - dimension   │    │                 │    │   📁 Structure: │    │   📥 Input:      │
│     Values      │    │   📋 Output:    │    │   ga_events_    │    │   - Landing     │
│   - metric      │    │   - Table       │    │   raw/date=     │    │     table       │
│     Values      │    │     schema      │    │   YYYY-MM-DD/   │    │   - JSON files  │
│   - processed_  │    │   - Metadata    │    │   part-*.parquet│    │   - GA4 data    │
│     at          │    │   - Statistics  │    │                 │    │                 │
│                 │    │                 │    │   📊 Schema:    │    │   📤 Output:     │
│   🔄 Schedule:  │    │   ⏰ Schedule:  │    │   - event_date  │    │   - Raw table   │
│   Continuous    │    │   Every 6 hours │    │   - page_path   │    │   - Parquet     │
│                 │    │                 │    │   - traffic_    │    │     files       │
│   🗂️ Database:  │    │   🗂️ Database: │    │     source      │    │   - Cleaned     │
│   analytics_    │    │   analytics_    │    │   - traffic_    │    │     data        │
│   landing       │    │   landing       │    │     medium      │    │                 │
│                 │    │                 │    │   - sessions    │    │   🔧 Technology:│
│   📋 Table:     │    │   📋 Table:     │    │   - total_users │    │   - PySpark     │
│   ga_events_    │    │   ga_events_    │    │   - screen_page_│    │   - Glue        │
│   landing       │    │   landing       │    │     views       │    │   - Dynamic     │
│                 │    │                 │    │   - event_count │    │     Frames      │
│   🔍 Crawler:   │    │   🔍 Crawler:   │    │   - processed_  │    │   - S3          │
│   ga_events_    │    │   ga_events_    │    │     at          │    │   - Parquet     │
│   landing_      │    │   landing_      │    │                 │    │                 │
│   crawler       │    │   crawler       │    │   🔄 Partition: │    │   ⏰ Runtime:    │
│                 │    │                 │    │   By date       │    │   15-30 min     │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### **3. Data Warehouse Layer (🟡)**
```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    🟡 DATA WAREHOUSE LAYER                                                   │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   🟢 Glue Job 2 │    │   🟡 Amazon     │    │   🟠 DBT Models │    │   🟠 Analytics  │
│   (Redshift     │───▶│   Redshift      │───▶│   (Transform)   │───▶│   Dashboard     │
│    Load)        │    │   (Internal)    │    │                 │    │   (BI Tools)    │
│                 │    │                 │    │                 │    │                 │
│   🔄 Process:   │    │   🏗️ Database:  │    │   🔧 Process:   │    │   📊 Visualize: │
│   - Read raw    │    │   analytics     │    │   - Read        │    │   - KPIs        │
│     table       │    │                 │    │     Redshift    │    │   - Charts      │
│   - Clean data  │    │   📋 Table:     │    │   - Apply       │    │   - Reports     │
│   - Load to     │    │   ga4_events_   │    │     business    │    │   - Alerts      │
│     Redshift    │    │   cleaned       │    │     logic       │    │                 │
│                 │    │                 │    │   - Calculate   │    │   📈 Metrics:   │
│   📥 Input:     │    │   📊 Schema:    │    │     metrics     │    │   - User        │
│   - Parquet     │    │   - event_date  │    │   - Create      │    │     behavior     │
│     files       │    │   - page_path   │    │     views       │    │   - Conversion   │
│   - Structured  │    │   - traffic_    │    │   - Data        │    │     rates        │
│     data        │    │     source      │    │     quality     │    │   - Traffic      │
│                 │    │   - traffic_    │    │                 │    │     sources      │
│   📤 Output:    │    │     medium      │    │   📤 Output:    │    │   - Page        │
│   - Redshift    │    │   - sessions    │    │   - Enhanced    │    │     performance  │
│     table       │    │   - total_users │    │   - Calculated  │    │   - Revenue      │
│   - Cleaned     │    │   - screen_page_│    │   - Business    │    │     tracking     │
│     data        │    │     views       │    │     fields      │    │                 │
│                 │    │   - event_count │    │   - Business    │    │   🔄 Refresh:   │
│   🔧 Technology:│    │   - processed_  │    │     metrics     │    │   Every 6 hours │
│   - JDBC        │    │     at          │    │                 │    │                 │
│   - Glue        │    │                 │    │   📋 Table:     │    │   🛠️ Tools:     │
│   - Redshift    │    │   🔍 Indexes:   │    │   ga4_events_   │    │   - Tableau     │
│                 │    │   - event_date  │    │   enhanced      │    │   - Power BI    │
│   ⏰ Runtime:    │    │   - page_path   │    │                 │    │   - Looker      │
│   10-20 min     │    │   - traffic_    │    │   📊 Schema:    │    │   - Grafana     │
│                 │    │     source      │    │   - All base    │    │   - Custom      │
│   🛡️ Security:  │    │                 │    │     fields      │    │     dashboards  │
│   - IAM role    │    │   🔄 Operations:│    │   - pages_per_  │    │                 │
│   - VPC         │    │   - INSERT      │    │     session     │    │   📊 Data       │
│   - Encryption  │    │   - UPDATE      │    │   - sessions_   │    │   Sources:      │
│                 │    │   - DELETE      │    │     per_user    │    │   - Redshift    │
│   📊 Preaction: │    │   - SELECT      │    │   - events_per_ │    │     internal     │
│   TRUNCATE      │    │                 │    │     session     │    │     tables       │
│   TABLE         │    │   🔐 Access:    │    │   - dbt_updated_│    │   - DBT models  │
│                 │    │   - IAM roles  │    │     at          │    │   - Real-time    │
└─────────────────┘    │   - Users      │    │                 │    │     updates      │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### **4. Data Querying Layer (🟠)**
```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    🟠 DATA QUERYING LAYER                                                   │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   🟡 S3 Raw     │    │   🟠 Redshift   │    │   🟠 Redshift   │    │   🟠 Business   │
│   Zone          │───▶│   Spectrum      │───▶│   Internal      │───▶│   Intelligence  │
│   (Parquet)     │    │   (External)    │    │   Tables        │    │   (Analytics)   │
│                 │    │                 │    │                 │    │                 │
│   🔍 Use Cases: │    │   🔍 Use Cases: │    │   🔍 Use Cases: │    │   🔍 Use Cases: │
│   - Ad-hoc      │    │   - Query S3    │    │   - Fast        │    │   - Business    │
│     queries     │    │     data        │    │     queries     │    │     metrics     │
│   - Data        │    │   - No data     │    │   - Aggregated  │    │   - KPIs        │
│     exploration │    │     movement    │    │     views       │    │   - Reports     │
│   - Cost-       │    │   - Pay per     │    │   - Optimized   │    │   - Alerts      │
│     effective   │    │     query       │    │     for speed   │    │   - Insights    │
│   - Large       │    │   - Unlimited   │    │   - Indexed     │    │                 │
│     datasets    │    │     scale       │    │     columns     │    │   📊 Output:    │
│                 │    │                 │    │                 │    │   - Enhanced    │
│   📊 Query      │    │   📊 Query      │    │   📊 Query      │    │     metrics     │
│   Example:      │    │   Example:      │    │   Example:      │    │   - Business    │
│   SELECT *      │    │   SELECT        │    │   SELECT        │    │     insights    │
│   FROM          │    │     date,       │    │     event_date, │    │   - Data        │
│   spectrum_     │    │     page_path,  │    │     page_path,  │    │     quality      │
│   analytics.    │    │     sessions    │    │     sessions,   │    │   - Performance │
│   ga_events_raw │    │   FROM          │    │     total_users │    │     indicators  │
│   WHERE         │    │   spectrum_     │    │   FROM          │    │                 │
│   date >=       │    │   analytics.    │    │   analytics.    │    │   📋 Tables:     │
│   '2024-01-01'  │    │   ga_events_raw │    │   ga4_events_   │    │   - ga4_events_ │
│                 │    │   WHERE         │    │   cleaned       │    │     enhanced     │
│   💰 Cost:      │    │   date >=       │    │   WHERE         │    │   - ga4_events_ │
│   Pay per       │    │   '2024-01-01'  │    │   event_date >= │    │     kpis         │
│   query         │    │                 │    │   '2024-01-01'  │    │   - ga4_events_ │
│                 │    │   💰 Cost:      │    │                 │    │     reports      │
│   🔄 Refresh:   │    │   Pay per       │    │   💰 Cost:      │    │                 │
│   Every 6 hours │    │   query         │    │   Fixed         │    │   🔄 Refresh:   │
│                 │    │                 │    │   monthly       │    │   Every 6 hours │
│   📁 Format:    │    │   🔄 Refresh:   │    │                 │    │                 │
│   Parquet       │    │   Real-time     │    │   🔄 Refresh:   │    │   🛠️ Tools:     │
│   (Optimized)   │    │                 │    │   Every 6 hours │    │   - DBT         │
│                 │    │   📁 Format:    │    │                 │    │   - SQL         │
│   🔐 Access:    │    │   External      │    │   📁 Format:    │    │   - Python      │
│   IAM roles     │    │   table         │    │   Internal      │    │   - R           │
└─────────────────┘    │                 │    │   table         │    │                 │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📋 **Data Flow Summary**

### **Step-by-Step Data Journey:**

1. **🔵 Data Source**: Google Analytics 4 Data API v1
   - **Input**: API calls with Property ID and date range
   - **Output**: Raw JSON response with dimensions and metrics

2. **🟢 Data Ingestion**: AWS Lambda Function
   - **Input**: GA4 API response
   - **Output**: JSON files stored in S3 Landing Zone
   - **Schedule**: Every 6 hours

3. **🟡 Data Discovery**: Glue Crawler 1
   - **Input**: S3 Landing Zone files
   - **Output**: Table schema in Glue Catalog
   - **Schedule**: Every 6 hours

4. **🟢 Data Processing**: Glue Job 1 (ETL)
   - **Input**: Raw JSON from landing table
   - **Output**: Structured Parquet files in S3 Raw Zone
   - **Transformations**: JSON parsing, data cleaning, partitioning

5. **🟡 Data Discovery**: Glue Crawler 2
   - **Input**: S3 Raw Zone Parquet files
   - **Output**: Table schema in Glue Catalog
   - **Schedule**: Every 6 hours

6. **🟢 Data Loading**: Glue Job 2 (Redshift Load)
   - **Input**: Parquet files from raw table
   - **Output**: Cleaned data in Redshift internal table
   - **Transformations**: Data validation, type casting

7. **🟠 Data Transformation**: DBT Models
   - **Input**: Redshift internal table
   - **Output**: Enhanced analytics table with calculated metrics
   - **Transformations**: Business logic, KPIs, data quality

8. **🟠 Data Consumption**: Analytics & BI
   - **Input**: Enhanced tables from Redshift and DBT
   - **Output**: Dashboards, reports, insights
   - **Tools**: Tableau, Power BI, custom dashboards

### **Data Formats & Transformations:**

| Stage | Input Format | Output Format | Key Transformations |
|-------|-------------|---------------|-------------------|
| **Source** | GA4 API JSON | - | API response structure |
| **Landing** | GA4 API JSON | JSON files | File storage, timestamping |
| **Raw** | JSON files | Parquet files | JSON parsing, schema creation, partitioning |
| **Internal** | Parquet files | Redshift table | Data cleaning, type casting, validation |
| **Enhanced** | Redshift table | Enhanced table | Business logic, calculated fields, KPIs |
| **Analytics** | Enhanced table | Dashboards | Visualization, reporting, insights |

This architecture provides a complete data pipeline from raw GA4 data to actionable business insights! 🚀 