# ChickTemp Data Dictionary

This data dictionary describes the Firebase Realtime Database paths and locally stored values used by the ChickTemp mobile application and ESP32-based monitoring system.

## users/{userId}

Stores the registered account information of each ChickTemp user.

| Field Name | Data Type | Description |
| --- | --- | --- |
| user_id | String | Unique identifier of the registered user. |
| full_name | String | Complete name of the user. |
| email_address | String | Email address used for login and account identification. |
| password_hash | String | Hashed password value used for authentication. |
| phone_number | String | Contact number of the user. |
| role | String | Role of the account, such as manager. |
| profile_photo_base64 | String | Base64 encoded profile photo of the user. |
| starts_with_empty_controls | Boolean | Indicates whether the user's control settings start empty by default. |

## users_by_email/{emailKey}

Maps an encoded email address to the corresponding user account.

| Field Name | Data Type | Description |
| --- | --- | --- |
| user_id | String | References the matching users/{userId} record. |
| emailKey | String | Base64URL encoded version of the user's email address. |

## support_tickets/{ticketId}

Stores support or help center messages submitted by users.

| Field Name | Data Type | Description |
| --- | --- | --- |
| ticket_id | String | Unique identifier of the support ticket. |
| subject | String | Subject or concern title submitted by the user. |
| message | String | Full support message or concern details. |
| created_at | ISO DateTime | Date and time when the support ticket was created. |
| status | String | Ticket status, such as open. |
| user_id | String | References the user who submitted the ticket. |
| full_name | String | Name of the user who submitted the ticket. |
| email_address | String | Email address of the user who submitted the ticket. |
| phone_number | String | Contact number of the user who submitted the ticket. |

## sensor/latest

Stores the most recent live sensor reading and device relay states from the ESP32.

| Field Name | Data Type | Description |
| --- | --- | --- |
| status | String | General sensor status, such as ok or no_read. |
| temperature | Number | Latest temperature reading. |
| humidity | Number | Latest humidity reading. |
| water_status | String | Water sensor status, such as ok or no_read. |
| water_level_percent | Number | Current water level percentage. |
| water_distance_cm | Number | Distance reading from the water level sensor in centimeters. |
| feeder_status | String | Feeder sensor status, such as ok or no_read. |
| feeder_level_percent | Number | Current feeder level percentage. |
| feeder_distance_cm | Number | Distance reading from the feeder level sensor in centimeters. |
| water_pump_enabled | Boolean | Indicates whether the water pump relay is enabled. |
| light_bulb_enabled | Boolean | Indicates whether the light bulb relay is enabled. |
| ventilation_fan_enabled | Boolean | Indicates whether the ventilation fan relay is enabled. |
| feeder_servo_enabled | Boolean | Indicates whether the feeder servo is enabled. |
| device | String | Device source of the reading, such as esp32-dht22-hcsr04. |
| updated_at | Server Timestamp | Time when the latest sensor data was updated. |

## environmental_logs/{logId}

Stores historical environmental readings used for monitoring and analytics.

| Field Name | Data Type | Description |
| --- | --- | --- |
| user_id | String | References the user who owns the log. |
| batch_id | String | References the batch connected to the reading. |
| device_id | String | Identifier of the device that produced the log. |
| temperature | Number | Recorded temperature value. |
| humidity | Number | Recorded humidity value. |
| sample_count | Number | Number of sensor samples included in the log. |
| aggregation_minutes | Number | Time interval used to aggregate readings, commonly 15 minutes. |
| water_level_percent | Number | Recorded water level percentage. |
| water_distance_cm | Number | Recorded water distance in centimeters. |
| feeder_level_percent | Number | Recorded feeder level percentage. |
| feeder_distance_cm | Number | Recorded feeder distance in centimeters. |
| recorded_at | Timestamp | Date and time when the environmental log was recorded. |

## controls/{batchKey}

Stores hardware control states read by the ESP32.

| Field Name | Data Type | Description |
| --- | --- | --- |
| water_pump.enabled | Boolean | Indicates whether the water pump should be turned on or off. |
| water_pump.source | String | Source of the water pump control update. |
| water_pump.updated_at | Timestamp | Time when the water pump control was last updated. |
| light_bulb.enabled | Boolean | Indicates whether the light bulb should be turned on or off. |
| light_bulb.source | String | Source of the light bulb control update. |
| light_bulb.updated_at | Timestamp | Time when the light bulb control was last updated. |
| ventilation_fan.enabled | Boolean | Indicates whether the ventilation fan should be turned on or off. |
| ventilation_fan.source | String | Source of the ventilation fan control update. |
| ventilation_fan.updated_at | Timestamp | Time when the ventilation fan control was last updated. |
| feeder_servo.enabled | Boolean | Indicates whether the feeder servo should be activated. |
| feeder_servo.source | String | Source of the feeder servo control update. |
| feeder_servo.updated_at | Timestamp | Time when the feeder servo control was last updated. |

## user_data/{userId}/batches/{batchId}

Stores the poultry batch records owned by each user.

| Field Name | Data Type | Description |
| --- | --- | --- |
| batch_id | String | Unique identifier of the poultry batch. |
| batch_name | String | Name assigned to the batch. |
| started_at_label | String | Display label for the batch start date. |
| day_label | String | Current batch day label, such as Day 1. |
| total_chickens | Number | Total number of chickens in the batch. |
| mortality_count | Number | Number of recorded chicken deaths in the batch. |
| is_active | Boolean | Indicates whether the batch is currently active. |

## user_data/{userId}/device_configs

Stores device configuration records for each user's batch.

| Field Name | Data Type | Description |
| --- | --- | --- |
| ventilation_configs/{batchKey} | Object | Ventilation configuration for a specific batch. |
| feeder_configs/{batchKey} | Object | Feeder configuration for a specific batch. |
| water_configs/{batchKey} | Object | Water system configuration for a specific batch. |
| lighting_configs/{batchKey} | Object | Lighting configuration for a specific batch. |
| main_enabled | Boolean | Indicates whether the device configuration is enabled. |
| expanded | Boolean | Indicates whether the configuration section is expanded in the app. |
| devices[] | Array | List of configured devices with name, id, type, description, and enabled state. |
| global_schedules[] | Array | List of global active or inactive schedules. |
| device_schedules[] | Array | List of schedules assigned to individual devices. |

## user_data/{userId}/mortality_records/{batchId}/{recordId}

Stores mortality records for each poultry batch.

| Field Name | Data Type | Description |
| --- | --- | --- |
| record_id | String | Unique identifier of the mortality record. |
| batch_id | String | References the batch where mortality was recorded. |
| deaths | Number | Number of chicken deaths recorded. |
| date | ISO DateTime | Date when the mortality was recorded. |
| note | String | Additional remarks about the mortality record. |
| recorded_at | Server Timestamp | Time when the mortality record was saved. |

## user_data/{userId}/report_records/{batchId}

Stores event and maintenance reports for each batch.

| Field Name | Data Type | Description |
| --- | --- | --- |
| events/{entryId} | Object | Event report entry for the batch. |
| maintenance/{entryId} | Object | Maintenance report entry for the batch. |
| title | String | Title of the report entry. |
| date | String | Date of the report in dd/mm/yyyy format. |
| description | String | Description or details of the report. |
| updated_at | ISO DateTime | Date and time when the report was last updated. |

## user_data/{userId}/latest_analytics_by_batch/{batchKey}

Stores the latest analytics summary for each batch.

| Field Name | Data Type | Description |
| --- | --- | --- |
| batch_name | String | Name of the batch being analyzed. |
| average_temperature | Number | Average temperature calculated from available readings. |
| average_humidity | Number | Average humidity calculated from available readings. |
| total_chickens | Number | Total number of chickens in the batch. |
| mortality_count | Number | Total number of recorded deaths. |
| alive_chickens | Number | Remaining live chickens after mortality is deducted. |
| survival_rate | Number | Percentage of surviving chickens. |
| water_tank_level | Number/Null | Current water tank level, or null if unavailable. |
| feeder_level | Number/Null | Current feeder level, or null if unavailable. |
| device_count | Number | Total number of configured devices. |
| active_schedule_count | Number | Number of active device schedules. |
| environmental_log_count | Number | Number of environmental logs used for analytics. |
| recorded_at | Server Timestamp | Time when the analytics summary was recorded. |

## user_data/{userId}/analytics_snapshots/{snapshotId}

Stores historical analytics snapshots for dashboard and analytics review.

| Field Name | Data Type | Description |
| --- | --- | --- |
| snapshot_id | String | Unique identifier of the analytics snapshot. |
| batch_name | String | Name of the batch included in the snapshot. |
| analytics_payload | Object | Same analytics data stored in latest_analytics_by_batch. |
| recorded_at | Server Timestamp | Time when the analytics snapshot was created. |

## Local SharedPreferences

Stores local application settings and cached values on the user's device. These values are not stored directly in Firebase.

| Field Name | Data Type | Description |
| --- | --- | --- |
| remember_me | Boolean | Indicates whether the app should remember the user's login preference. |
| remembered_email | String | Locally stored email address used for login convenience. |
| cached_batches | Object/List | Locally cached batch records for faster loading. |
| cached_telemetry | Object | Locally cached sensor or telemetry readings. |
| temperature_threshold_settings | Object | Local temperature alert threshold settings. |
| alert_preferences | Object | Local notification and alert preferences. |
| read_alert_ids | List | List of alert IDs already read by the user. |
| cached_environmental_logs | Object/List | Locally cached environmental logs for offline sync. |
