# Google Analytics 4 Pipeline - Architecture Diagram

## Complete System Architecture

```mermaid
graph TB
    subgraph "External Data Source"
        GA4[Google Analytics 4<br/>Data API v1]
    end
    
    subgraph "Data Ingestion Layer"
        LAMBDA[AWS Lambda Function<br/>ga_ingest.py<br/>Scheduled every 6 hours]
        CW[CloudWatch Logs<br/>Monitoring & Debugging]
    end
    
    subgraph "Data Storage Layer"
        subgraph "S3 Data Lake"
            S3_LANDING[S3 Landing Zone<br/>Raw JSON Files<br/>ga4_events_YYYY-MM-DD_HHMMSS.json]
            S3_RAW[S3 Raw Zone<br/>Processed Parquet Files<br/>Partitioned by date]
            S3_TMP[S3 Temporary<br/>Glue Job Staging]
        end
    end
    
    subgraph "Data Processing Layer"
        subgraph "AWS Glue"
            CRAWLER1[Glue Crawler 1<br/>Landing Zone<br/>Creates metadata tables]
            CRAWLER2[Glue Crawler 2<br/>Raw Zone<br/>Updates metadata tables]
            JOB1[Glue Job 1<br/>ga_landing_to_raw.py<br/>JSON to Parquet ETL]
            JOB2[Glue Job 2<br/>ga_to_redshift.py<br/>Load to Redshift]
            CATALOG[Glue Data Catalog<br/>Central metadata repository]
        end
    end
    
    subgraph "Data Warehouse Layer"
        subgraph "Amazon Redshift"
            RS_INTERNAL[Redshift Internal Tables<br/>analytics.ga4_events_cleaned<br/>Curated data for reporting]
            RS_SPECTRUM[Redshift Spectrum<br/>Query S3 data directly<br/>External tables]
        end
    end
    
    subgraph "Data Transformation Layer"
        DBT[DBT Models<br/>ga_events_cleaned.sql<br/>Business logic & KPIs]
    end
    
    subgraph "Orchestration Layer"
        SF[Step Functions<br/>State Machine<br/>Pipeline orchestration]
    end
    
    subgraph "Infrastructure Layer"
        subgraph "Terraform"
            TF_S3[Terraform S3<br/>Bucket creation & policies]
            TF_IAM[Terraform IAM<br/>Roles & permissions]
            TF_GLUE[Terraform Glue<br/>Databases & crawlers]
        end
    end
    
    %% Data Flow Connections
    GA4 -->|API Calls| LAMBDA
    LAMBDA -->|JSON Data| S3_LANDING
    LAMBDA -->|Logs| CW
    
    S3_LANDING -->|Scan| CRAWLER1
    CRAWLER1 -->|Metadata| CATALOG
    CATALOG -->|Read| JOB1
    JOB1 -->|Processed Data| S3_RAW
    
    S3_RAW -->|Scan| CRAWLER2
    CRAWLER2 -->|Metadata| CATALOG
    CATALOG -->|Read| JOB2
    JOB2 -->|Clean Data| RS_INTERNAL
    
    S3_RAW -->|Query| RS_SPECTRUM
    RS_INTERNAL -->|Transform| DBT
    
    %% Orchestration
    SF -->|Trigger| LAMBDA
    SF -->|Start| CRAWLER1
    SF -->|Execute| JOB1
    SF -->|Start| CRAWLER2
    SF -->|Execute| JOB2
    
    %% Infrastructure
    TF_S3 --> S3_LANDING
    TF_S3 --> S3_RAW
    TF_S3 --> S3_TMP
    TF_IAM --> LAMBDA
    TF_IAM --> JOB1
    TF_IAM --> JOB2
    TF_GLUE --> CRAWLER1
    TF_GLUE --> CRAWLER2
    TF_GLUE --> CATALOG
    
    %% Styling
    classDef external fill:#ff9999,stroke:#333,stroke-width:2px
    classDef ingestion fill:#99ccff,stroke:#333,stroke-width:2px
    classDef storage fill:#99ff99,stroke:#333,stroke-width:2px
    classDef processing fill:#ffcc99,stroke:#333,stroke-width:2px
    classDef warehouse fill:#cc99ff,stroke:#333,stroke-width:2px
    classDef transformation fill:#ffff99,stroke:#333,stroke-width:2px
    classDef orchestration fill:#ff99cc,stroke:#333,stroke-width:2px
    classDef infrastructure fill:#99ffff,stroke:#333,stroke-width:2px
    
    class GA4 external
    class LAMBDA,CW ingestion
    class S3_LANDING,S3_RAW,S3_TMP storage
    class CRAWLER1,CRAWLER2,JOB1,JOB2,CATALOG processing
    class RS_INTERNAL,RS_SPECTRUM warehouse
    class DBT transformation
    class SF orchestration
    class TF_S3,TF_IAM,TF_GLUE infrastructure
```

## Detailed Component Architecture

### 1. Data Ingestion Flow

```mermaid
sequenceDiagram
    participant Scheduler as EventBridge Scheduler
    participant Lambda as Lambda Function
    participant GA4 as GA4 API
    participant S3 as S3 Landing Zone
    participant CW as CloudWatch Logs
    
    Scheduler->>Lambda: Trigger every 6 hours
    Lambda->>Lambda: Calculate yesterday's date
    Lambda->>GA4: POST /properties/{ID}:runReport
    GA4-->>Lambda: JSON response with metrics
    Lambda->>Lambda: Process response
    Lambda->>S3: Upload JSON file
    Lambda->>CW: Log execution details
    Lambda-->>Scheduler: Return success/failure
```

### 2. Data Processing Flow

```mermaid
sequenceDiagram
    participant SF as Step Functions
    participant Crawler as Glue Crawler
    participant Catalog as Glue Catalog
    participant Job as Glue Job
    participant S3_Landing as S3 Landing
    participant S3_Raw as S3 Raw Zone
    
    SF->>Crawler: Start crawler
    Crawler->>S3_Landing: Scan for new files
    Crawler->>Catalog: Update table metadata
    Crawler-->>SF: Crawler complete
    SF->>Job: Start ETL job
    Job->>Catalog: Read table schema
    Job->>S3_Landing: Read JSON data
    Job->>Job: Transform to structured format
    Job->>S3_Raw: Write Parquet files
    Job-->>SF: Job complete
```

### 3. Data Loading Flow

```mermaid
sequenceDiagram
    participant Job as Glue Job
    participant S3_Raw as S3 Raw Zone
    participant S3_Tmp as S3 Temporary
    participant Redshift as Amazon Redshift
    
    Job->>S3_Raw: Read Parquet data
    Job->>Job: Clean and validate data
    Job->>S3_Tmp: Stage data for loading
    Job->>Redshift: COPY command
    Redshift->>S3_Tmp: Load staged data
    Redshift-->>Job: Load complete
    Job->>S3_Tmp: Clean up temporary files
```

## Data Transformation Architecture

### DBT Model Structure

```mermaid
graph LR
    subgraph "Source Layer"
        SRC[analytics_raw.ga_events_raw<br/>Raw GA4 data from S3]
    end
    
    subgraph "Staging Layer"
        STG[staging.ga4_events_staged<br/>Cleaned and validated data]
    end
    
    subgraph "Analytics Layer"
        FCT[analytics.ga4_events_cleaned<br/>Final analytics table with KPIs]
    end
    
    subgraph "Calculated Metrics"
        KPIS[Business KPIs<br/>• Pages per session<br/>• Sessions per user<br/>• Events per session]
    end
    
    SRC --> STG
    STG --> FCT
    FCT --> KPIS
```

## Infrastructure Architecture

### AWS Resource Dependencies

```mermaid
graph TD
    subgraph "Core Infrastructure"
        VPC[VPC & Networking]
        IAM[IAM Roles & Policies]
    end
    
    subgraph "Storage Layer"
        S3[S3 Bucket]
        S3_Versioning[S3 Versioning]
        S3_Lifecycle[S3 Lifecycle Policies]
    end
    
    subgraph "Compute Layer"
        LAMBDA[Lambda Function]
        GLUE_JOBS[Glue Jobs]
        GLUE_CRAWLERS[Glue Crawlers]
    end
    
    subgraph "Data Layer"
        GLUE_CATALOG[Glue Data Catalog]
        GLUE_DB[Glue Databases]
        REDSHIFT[Redshift Cluster]
    end
    
    subgraph "Orchestration"
        SF[Step Functions]
        CW[CloudWatch]
    end
    
    VPC --> S3
    IAM --> LAMBDA
    IAM --> GLUE_JOBS
    IAM --> GLUE_CRAWLERS
    S3 --> S3_Versioning
    S3 --> S3_Lifecycle
    S3 --> GLUE_CRAWLERS
    GLUE_CRAWLERS --> GLUE_CATALOG
    GLUE_CATALOG --> GLUE_DB
    GLUE_JOBS --> REDSHIFT
    SF --> LAMBDA
    SF --> GLUE_CRAWLERS
    SF --> GLUE_JOBS
    CW --> LAMBDA
    CW --> GLUE_JOBS
```

## Security Architecture

### IAM Role Permissions

```mermaid
graph TB
    subgraph "Lambda Role"
        LAMBDA_ROLE[ga-lambda-role]
        LAMBDA_S3[Allow: s3:PutObject, s3:GetObject]
        LAMBDA_LOGS[Allow: logs:CreateLogGroup, logs:PutLogEvents]
    end
    
    subgraph "Glue Role"
        GLUE_ROLE[ga-glue-role]
        GLUE_S3[Allow: s3:GetObject, s3:PutObject, s3:DeleteObject]
        GLUE_CATALOG[Allow: glue:GetTable, glue:CreateTable]
        GLUE_REDSHIFT[Allow: redshift:DescribeClusters]
    end
    
    subgraph "Step Functions Role"
        SF_ROLE[step-functions-role]
        SF_LAMBDA[Allow: lambda:InvokeFunction]
        SF_GLUE[Allow: glue:StartCrawler, glue:StartJobRun]
    end
    
    LAMBDA_ROLE --> LAMBDA_S3
    LAMBDA_ROLE --> LAMBDA_LOGS
    GLUE_ROLE --> GLUE_S3
    GLUE_ROLE --> GLUE_CATALOG
    GLUE_ROLE --> GLUE_REDSHIFT
    SF_ROLE --> SF_LAMBDA
    SF_ROLE --> SF_GLUE
```

## Data Flow Architecture

### End-to-End Data Journey

```mermaid
flowchart LR
    subgraph "Source"
        GA4_API[GA4 API<br/>JSON Response]
    end
    
    subgraph "Landing"
        LANDING_JSON[Raw JSON<br/>S3 Landing Zone]
    end
    
    subgraph "Processing"
        PROCESSED_PARQUET[Processed Parquet<br/>S3 Raw Zone]
    end
    
    subgraph "Warehouse"
        REDSHIFT_TABLE[Redshift Table<br/>analytics.ga4_events_cleaned]
    end
    
    subgraph "Analytics"
        DBT_MODEL[DBT Model<br/>Business KPIs]
    end
    
    subgraph "Query Options"
        SPECTRUM[Redshift Spectrum<br/>Query S3 directly]
        INTERNAL[Redshift Internal<br/>Query curated tables]
    end
    
    GA4_API --> LANDING_JSON
    LANDING_JSON --> PROCESSED_PARQUET
    PROCESSED_PARQUET --> REDSHIFT_TABLE
    REDSHIFT_TABLE --> DBT_MODEL
    PROCESSED_PARQUET --> SPECTRUM
    DBT_MODEL --> INTERNAL
```

## Monitoring Architecture

### Observability Stack

```mermaid
graph TB
    subgraph "Data Sources"
        LAMBDA_LOGS[Lambda CloudWatch Logs]
        GLUE_LOGS[Glue Job Logs]
        SF_LOGS[Step Functions Execution Logs]
        S3_METRICS[S3 Metrics]
    end
    
    subgraph "Monitoring"
        CW_METRICS[CloudWatch Metrics]
        CW_ALARMS[CloudWatch Alarms]
        CW_DASHBOARD[CloudWatch Dashboard]
    end
    
    subgraph "Alerting"
        SNS[SNS Notifications]
        EMAIL[Email Alerts]
        SLACK[Slack Notifications]
    end
    
    LAMBDA_LOGS --> CW_METRICS
    GLUE_LOGS --> CW_METRICS
    SF_LOGS --> CW_METRICS
    S3_METRICS --> CW_METRICS
    
    CW_METRICS --> CW_ALARMS
    CW_ALARMS --> SNS
    SNS --> EMAIL
    SNS --> SLACK
    
    CW_METRICS --> CW_DASHBOARD
```

## Cost Optimization Architecture

### Resource Scaling Strategy

```mermaid
graph LR
    subgraph "On-Demand Resources"
        LAMBDA_ON[Lambda<br/>Pay per invocation]
        S3_ON[S3<br/>Pay per GB stored]
    end
    
    subgraph "Scheduled Resources"
        GLUE_JOBS[Glue Jobs<br/>Pay per DPU-hour]
        CRAWLERS[Crawlers<br/>Pay per crawl]
    end
    
    subgraph "Optimization Strategies"
        LIFECYCLE[S3 Lifecycle<br/>Move to cheaper storage]
        PARTITIONING[Data Partitioning<br/>Reduce scan costs]
        COMPRESSION[Parquet Compression<br/>Reduce storage costs]
    end
    
    LAMBDA_ON --> LIFECYCLE
    S3_ON --> LIFECYCLE
    GLUE_JOBS --> PARTITIONING
    CRAWLERS --> PARTITIONING
    S3_ON --> COMPRESSION
```

This architecture diagram provides a comprehensive view of how all components in your Google Analytics 4 pipeline work together, from data ingestion to final analytics, including security, monitoring, and cost optimization considerations. 