-- DBT Model: Clean and transform Google Analytics 4 data
{{ config(
    materialized = 'table',
    schema = 'analytics',
    alias = 'ga4_events_cleaned',
    file_format = 'delta'
) }}

WITH cleaned_ga4_data AS (
    SELECT
        event_date,
        page_path,
        traffic_source,
        traffic_medium,
        sessions,
        total_users,
        screen_page_views,
        event_count,
        processed_at,
        -- Add calculated fields for GA4
        CASE 
            WHEN sessions > 0 THEN ROUND(CAST(screen_page_views AS FLOAT) / sessions, 2)
            ELSE 0 
        END AS pages_per_session,
        CASE 
            WHEN total_users > 0 THEN ROUND(CAST(sessions AS FLOAT) / total_users, 2)
            ELSE 0 
        END AS sessions_per_user,
        CASE 
            WHEN sessions > 0 THEN ROUND(CAST(event_count AS FLOAT) / sessions, 2)
            ELSE 0 
        END AS events_per_session
    FROM {{ source('analytics_raw', 'ga_events_raw') }}
    WHERE event_date IS NOT NULL
      AND page_path IS NOT NULL
      AND sessions >= 0
      AND total_users >= 0
      AND screen_page_views >= 0
      AND event_count >= 0
)

SELECT 
    event_date,
    page_path,
    traffic_source,
    traffic_medium,
    sessions,
    total_users,
    screen_page_views,
    event_count,
    pages_per_session,
    sessions_per_user,
    events_per_session,
    processed_at,
    CURRENT_TIMESTAMP AS dbt_updated_at
FROM cleaned_ga4_data 