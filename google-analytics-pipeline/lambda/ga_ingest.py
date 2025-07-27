import json
import boto3
import requests
from datetime import datetime, timedelta
import os

# Initialize AWS clients
s3 = boto3.client('s3')
BUCKET = os.environ.get('S3_BUCKET', 'my-ga-analytics-data')
LANDING_PATH = 'landing/ga_events/'

# Google Analytics 4 API configuration
GA_API_KEY = ''  # Your API key
GA4_PROPERTY_ID = 'YOUR_PROPERTY_ID'  # Replace with your GA4 property ID (format: 123456789)

def get_ga4_data(start_date, end_date):
    """Fetch data from Google Analytics 4 Data API v1"""
    
    # Google Analytics Data API v1 endpoint
    url = f"https://analyticsdata.googleapis.com/v1beta/properties/{GA4_PROPERTY_ID}:runReport?key={GA_API_KEY}"
    
    # GA4 request body - modify based on your needs
    request_body = {
        "dateRanges": [
            {
                "startDate": start_date,
                "endDate": end_date
            }
        ],
        "dimensions": [
            {"name": "date"},
            {"name": "pagePath"},
            {"name": "source"},
            {"name": "medium"}
        ],
        "metrics": [
            {"name": "sessions"},
            {"name": "totalUsers"},
            {"name": "screenPageViews"},
            {"name": "eventCount"}
        ],
        "limit": 10000  # Adjust based on your data volume
    }
    
    try:
        response = requests.post(url, json=request_body)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching GA4 data: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response status: {e.response.status_code}")
            print(f"Response body: {e.response.text}")
        return None

def lambda_handler(event, context):
    """Main Lambda handler function"""
    
    try:
        # Get yesterday's date for data collection
        yesterday = datetime.now() - timedelta(days=1)
        start_date = yesterday.strftime('%Y-%m-%d')
        end_date = yesterday.strftime('%Y-%m-%d')
        
        print(f"Fetching GA4 data for {start_date}")
        print(f"Property ID: {GA4_PROPERTY_ID}")
        
        # Fetch data from Google Analytics 4
        ga4_data = get_ga4_data(start_date, end_date)
        
        if not ga4_data:
            return {
                'statusCode': 500,
                'body': json.dumps('Failed to fetch GA4 data')
            }
        
        # Create filename with timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        file_name = f"{LANDING_PATH}ga4_events_{start_date}_{timestamp}.json"
        
        # Upload to S3
        s3.put_object(
            Bucket=BUCKET,
            Key=file_name,
            Body=json.dumps(ga4_data, indent=2),
            ContentType='application/json'
        )
        
        print(f"Successfully uploaded {file_name} to S3")
        print(f"Data summary: {len(ga4_data.get('rows', []))} rows fetched")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'GA4 data successfully ingested',
                'file': file_name,
                'date': start_date,
                'rows_count': len(ga4_data.get('rows', []))
            })
        }
        
    except Exception as e:
        print(f"Error in lambda_handler: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        } 