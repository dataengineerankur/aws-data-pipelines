
# AWS Data Pipelines 🚀

A collection of end-to-end, production-grade data pipeline templates using AWS cloud-native services.  
Each pipeline demonstrates best practices for scalable data ingestion, processing, data quality, and analytics using services such as S3, Glue, Lambda, Redshift, Step Functions, Athena, and more.

## 📦 Repository Structure

```plaintext
aws-data-pipelines/
|
├── google-analytics-pipeline/
|   ├── terraform/           # Infrastructure as code for S3, Glue, etc.
|   ├── lambda/              # Lambda functions for API ingestion
|   ├── glue_jobs/           # Glue ETL scripts
|   ├── step_function/       # Step Function workflow definitions
|   ├── dbt_models/          # DBT models for transformations (if used)
|   ├── README.md            # Pipeline-specific documentation
|   └── ...                  # Other related scripts/configs
|
├── [future-pipeline-name]/
|   └── ...
|
└── README.md                # (This file)

```

## ✨ Available Pipelines

### 1. **Google Analytics Pipeline**
End-to-end serverless pipeline that ingests Google Analytics event/campaign data and processes it for analytics and BI.

- **Ingestion**: Lambda function or Glue Python Shell pulls data from GA API into S3 (landing zone)
- **Schema discovery**: Glue Crawler registers table in Glue Catalog
- **Transformation**: Glue Spark jobs cleanse and partition raw data, write to raw/clean zones
- **Metadata management**: Glue Catalog tables for landing and raw data
- **Analytics & reporting**:  
  - Redshift Spectrum for ad hoc queries on raw S3 data  
  - Internal Redshift tables for BI/reporting/dashboarding
- **Orchestration**: AWS Step Functions
- **Data Quality**: Example of Glue Data Quality rules

*See* `google-analytics-pipeline/README.md` *for full details.*

---

### 2. [Future Pipeline Example]
Describe future pipelines here (e.g. Salesforce, Shopify, CDC, Kinesis streaming, etc.).

---

## 🏗️ How to Use

Each pipeline is organized as a **modular folder** with its own documentation and code.  
To deploy a pipeline, follow the `README.md` in its directory.

**Example: Deploying the Google Analytics Pipeline**
1. `cd google-analytics-pipeline/terraform`
2. `terraform init && terraform apply`  
   _(provisions S3, Glue DBs, Crawlers, etc.)_
3. Deploy Lambda and Glue Jobs as per `lambda/` and `glue_jobs/`
4. Create or update Step Function with workflow JSON from `step_function/`
5. Run jobs or trigger Step Function to start the pipeline

---

## 📚 Best Practices Demonstrated

- Serverless & event-driven data ingestion (Lambda, Step Functions)
- Scalable storage and schema evolution using S3 and Glue Catalog
- Orchestration of ETL steps using Step Functions
- Ad hoc and scheduled queries using Athena & Redshift Spectrum
- Data quality enforcement using AWS Glue DQ and/or PyDeequ
- Modular and reproducible infra with Terraform

---

## 🤝 Contributing

- PRs for new pipelines, bugfixes, or enhancements are welcome!
- Please structure new pipelines under their own directory, following the same template.
- Add a README for each pipeline.

---

## 📖 License

MIT License.

---

## 📝 Maintainers

- [Ankur Chopra](https://github.com/dataengineerankur)
