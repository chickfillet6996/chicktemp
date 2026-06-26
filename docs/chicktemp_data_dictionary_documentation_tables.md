# ChickTemp Data Dictionary Tables

Note: ChickTemp uses Firebase Realtime Database, which is a NoSQL JSON database. The tables below are formatted in relational-documentation style for capstone documentation. Constraint types such as `PRIMARY KEY`, `FOREIGN KEY`, and `UNIQUE` describe the role of each field in the system design.

## 1. User Table

Firebase Path: `users/{userId}`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| user_id | character varying | NO | NULL | PRIMARY KEY | Unique identifier for the user account. |
| full_name | character varying | NO | NULL | - | Full name of the farm owner or manager. |
| email_address | character varying | NO | NULL | UNIQUE | Email address used for login and notification. |
| password_hash | character varying | NO | NULL | - | Encrypted password used for system authentication. |
| phone_number | character varying | YES | NULL | - | Contact number of the user. |
| role | character varying | NO | manager | - | Account role assigned to the user. |
| profile_photo_base64 | text | YES | NULL | - | Base64 encoded profile photo of the user. |
| starts_with_empty_controls | boolean | NO | false | - | Indicates if the user's control settings start empty by default. |

## 2. Users by Email Table

Firebase Path: `users_by_email/{emailKey}`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| email_key | character varying | NO | NULL | PRIMARY KEY | Base64URL encoded email address used as the record key. |
| user_id | character varying | NO | NULL | FOREIGN KEY | References the matching record in `users/{userId}`. |

## 3. Support Ticket Table

Firebase Path: `support_tickets/{ticketId}`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| ticket_id | character varying | NO | NULL | PRIMARY KEY | Unique identifier for the support ticket. |
| subject | character varying | NO | NULL | - | Subject or title of the user's concern. |
| message | text | NO | NULL | - | Full support message submitted by the user. |
| created_at | datetime | NO | NULL | - | Date and time when the ticket was created. |
| status | character varying | NO | open | - | Current status of the support ticket. |
| user_id | character varying | NO | NULL | FOREIGN KEY | References the user who submitted the support ticket. |
| full_name | character varying | NO | NULL | - | Name of the user who submitted the ticket. |
| email_address | character varying | NO | NULL | - | Email address of the user who submitted the ticket. |
| phone_number | character varying | YES | NULL | - | Contact number of the user who submitted the ticket. |

## 4. Live Sensor Table

Firebase Path: `sensor/latest`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| status | character varying | NO | no_read | - | General sensor reading status, such as `ok` or `no_read`. |
| temperature | numeric | YES | NULL | - | Latest temperature reading from the DHT22 sensor. |
| humidity | numeric | YES | NULL | - | Latest humidity reading from the DHT22 sensor. |
| water_status | character varying | NO | no_read | - | Status of the water level reading. |
| water_level_percent | numeric | YES | NULL | - | Current water level percentage. |
| water_distance_cm | numeric | YES | NULL | - | Distance reading from the water level sensor in centimeters. |
| feeder_status | character varying | NO | no_read | - | Status of the feeder level reading. |
| feeder_level_percent | numeric | YES | NULL | - | Current feeder level percentage. |
| feeder_distance_cm | numeric | YES | NULL | - | Distance reading from the feeder level sensor in centimeters. |
| water_pump_enabled | boolean | NO | false | - | Indicates whether the water pump relay is enabled. |
| light_bulb_enabled | boolean | NO | false | - | Indicates whether the light bulb relay is enabled. |
| ventilation_fan_enabled | boolean | NO | false | - | Indicates whether the ventilation fan relay is enabled. |
| feeder_servo_enabled | boolean | NO | false | - | Indicates whether the feeder servo is enabled. |
| device | character varying | NO | NULL | - | Name or identifier of the ESP32 device source. |
| updated_at | timestamp | NO | NULL | - | Date and time when the latest sensor data was updated. |

## 5. Environmental Log Table

Firebase Path: `environmental_logs/{logId}`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| log_id | character varying | NO | NULL | PRIMARY KEY | Unique identifier for the environmental log. |
| user_id | character varying | NO | NULL | FOREIGN KEY | References the user who owns the environmental log. |
| batch_id | character varying | NO | NULL | FOREIGN KEY | References the batch connected to the reading. |
| device_id | character varying | NO | NULL | - | Identifier of the device that produced the log. |
| temperature | numeric | NO | NULL | - | Recorded temperature value. |
| humidity | numeric | NO | NULL | - | Recorded humidity value. |
| sample_count | integer | NO | 0 | - | Number of sensor samples included in the log. |
| aggregation_minutes | integer | NO | 15 | - | Time interval used to aggregate sensor readings. |
| water_level_percent | numeric | YES | NULL | - | Recorded water level percentage. |
| water_distance_cm | numeric | YES | NULL | - | Recorded water distance in centimeters. |
| feeder_level_percent | numeric | YES | NULL | - | Recorded feeder level percentage. |
| feeder_distance_cm | numeric | YES | NULL | - | Recorded feeder distance in centimeters. |
| recorded_at | timestamp | NO | NULL | - | Date and time when the environmental log was recorded. |

## 6. Control Table

Firebase Path: `controls/{batchKey}`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| batch_key | character varying | NO | NULL | PRIMARY KEY | Unique batch key used for hardware control records. |
| water_pump_enabled | boolean | NO | false | - | Indicates whether the water pump should be turned on or off. |
| water_pump_source | character varying | YES | NULL | - | Source of the water pump control update. |
| water_pump_updated_at | timestamp | YES | NULL | - | Date and time when the water pump control was updated. |
| light_bulb_enabled | boolean | NO | false | - | Indicates whether the light bulb should be turned on or off. |
| light_bulb_source | character varying | YES | NULL | - | Source of the light bulb control update. |
| light_bulb_updated_at | timestamp | YES | NULL | - | Date and time when the light bulb control was updated. |
| ventilation_fan_enabled | boolean | NO | false | - | Indicates whether the ventilation fan should be turned on or off. |
| ventilation_fan_source | character varying | YES | NULL | - | Source of the ventilation fan control update. |
| ventilation_fan_updated_at | timestamp | YES | NULL | - | Date and time when the ventilation fan control was updated. |
| feeder_servo_enabled | boolean | NO | false | - | Indicates whether the feeder servo should be activated. |
| feeder_servo_source | character varying | YES | NULL | - | Source of the feeder servo control update. |
| feeder_servo_updated_at | timestamp | YES | NULL | - | Date and time when the feeder servo control was updated. |

## 7. Batch Table

Firebase Path: `user_data/{userId}/batches/{batchId}`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| batch_id | character varying | NO | NULL | PRIMARY KEY | Unique identifier for the poultry batch. |
| user_id | character varying | NO | NULL | FOREIGN KEY | References the user who owns the batch. |
| batch_name | character varying | NO | NULL | - | Name assigned to the poultry batch. |
| started_at_label | character varying | NO | NULL | - | Display label for the batch start date. |
| day_label | character varying | NO | NULL | - | Current batch day label. |
| total_chickens | integer | NO | 0 | - | Total number of chickens in the batch. |
| mortality_count | integer | NO | 0 | - | Total number of recorded chicken deaths. |
| is_active | boolean | NO | true | - | Indicates whether the batch is currently active. |

## 8. Device Configuration Table

Firebase Path: `user_data/{userId}/device_configs`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| user_id | character varying | NO | NULL | FOREIGN KEY | References the owner of the device configuration. |
| batch_key | character varying | NO | NULL | FOREIGN KEY | References the batch connected to the configuration. |
| config_type | character varying | NO | NULL | - | Type of device configuration, such as ventilation, feeder, water, or lighting. |
| main_enabled | boolean | NO | false | - | Indicates whether the configuration is enabled. |
| expanded | boolean | NO | false | - | Indicates whether the configuration section is expanded in the app. |
| devices | array | YES | NULL | - | List of configured devices with name, id, type, description, and enabled state. |
| global_schedules | array | YES | NULL | - | List of global active or inactive schedules. |
| device_schedules | array | YES | NULL | - | List of schedules assigned to individual devices. |
| fan_speed | numeric | YES | NULL | - | Ventilation fan speed value, if applicable. |
| lighting_brightness | numeric | YES | NULL | - | Lighting brightness value, if applicable. |

## 9. Mortality Record Table

Firebase Path: `user_data/{userId}/mortality_records/{batchId}/{recordId}`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| record_id | character varying | NO | NULL | PRIMARY KEY | Unique identifier for the mortality record. |
| user_id | character varying | NO | NULL | FOREIGN KEY | References the user who owns the mortality record. |
| batch_id | character varying | NO | NULL | FOREIGN KEY | References the batch where mortality was recorded. |
| deaths | integer | NO | 0 | - | Number of chicken deaths recorded. |
| date | datetime | NO | NULL | - | Date when the mortality was recorded. |
| note | text | YES | NULL | - | Additional notes or remarks about the mortality record. |
| recorded_at | timestamp | NO | NULL | - | Date and time when the mortality record was saved. |

## 10. Report Record Table

Firebase Path: `user_data/{userId}/report_records/{batchId}`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| entry_id | character varying | NO | NULL | PRIMARY KEY | Unique identifier for the report entry. |
| user_id | character varying | NO | NULL | FOREIGN KEY | References the user who owns the report entry. |
| batch_id | character varying | NO | NULL | FOREIGN KEY | References the batch connected to the report. |
| report_type | character varying | NO | NULL | - | Type of report, such as event or maintenance. |
| title | character varying | NO | NULL | - | Title of the report entry. |
| date | character varying | NO | NULL | - | Date of the report in `dd/mm/yyyy` format. |
| description | text | NO | NULL | - | Description or details of the report. |
| updated_at | datetime | NO | NULL | - | Date and time when the report was last updated. |

## 11. Latest Analytics by Batch Table

Firebase Path: `user_data/{userId}/latest_analytics_by_batch/{batchKey}`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| batch_key | character varying | NO | NULL | PRIMARY KEY | Unique batch key used for the analytics summary. |
| user_id | character varying | NO | NULL | FOREIGN KEY | References the user who owns the analytics record. |
| batch_name | character varying | NO | NULL | - | Name of the batch being analyzed. |
| average_temperature | numeric | YES | NULL | - | Average temperature calculated from available readings. |
| average_humidity | numeric | YES | NULL | - | Average humidity calculated from available readings. |
| total_chickens | integer | NO | 0 | - | Total number of chickens in the batch. |
| mortality_count | integer | NO | 0 | - | Total number of recorded deaths. |
| alive_chickens | integer | NO | 0 | - | Number of remaining live chickens. |
| survival_rate | numeric | NO | 0 | - | Percentage of surviving chickens. |
| water_tank_level | numeric | YES | NULL | - | Current water tank level, if available. |
| feeder_level | numeric | YES | NULL | - | Current feeder level, if available. |
| device_count | integer | NO | 0 | - | Total number of configured devices. |
| active_schedule_count | integer | NO | 0 | - | Number of active device schedules. |
| environmental_log_count | integer | NO | 0 | - | Number of environmental logs used for analytics. |
| recorded_at | timestamp | NO | NULL | - | Date and time when the analytics summary was recorded. |

## 12. Analytics Snapshot Table

Firebase Path: `user_data/{userId}/analytics_snapshots/{snapshotId}`

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| snapshot_id | character varying | NO | NULL | PRIMARY KEY | Unique identifier for the analytics snapshot. |
| user_id | character varying | NO | NULL | FOREIGN KEY | References the user who owns the analytics snapshot. |
| batch_name | character varying | NO | NULL | - | Name of the batch included in the snapshot. |
| average_temperature | numeric | YES | NULL | - | Average temperature stored in the snapshot. |
| average_humidity | numeric | YES | NULL | - | Average humidity stored in the snapshot. |
| total_chickens | integer | NO | 0 | - | Total number of chickens at the time of the snapshot. |
| mortality_count | integer | NO | 0 | - | Total deaths at the time of the snapshot. |
| alive_chickens | integer | NO | 0 | - | Remaining live chickens at the time of the snapshot. |
| survival_rate | numeric | NO | 0 | - | Survival rate at the time of the snapshot. |
| water_tank_level | numeric | YES | NULL | - | Water tank level at the time of the snapshot. |
| feeder_level | numeric | YES | NULL | - | Feeder level at the time of the snapshot. |
| device_count | integer | NO | 0 | - | Number of configured devices at the time of the snapshot. |
| active_schedule_count | integer | NO | 0 | - | Number of active schedules at the time of the snapshot. |
| environmental_log_count | integer | NO | 0 | - | Number of environmental logs included in the snapshot. |
| recorded_at | timestamp | NO | NULL | - | Date and time when the analytics snapshot was created. |

## 13. Local SharedPreferences Table

Storage Location: Mobile device local storage

| Column Name | Data Type | Is Nullable | Column Default | Constraint Type | Description |
| --- | --- | --- | --- | --- | --- |
| remember_me | boolean | NO | false | - | Indicates whether the app should remember the user's login preference. |
| remembered_email | character varying | YES | NULL | - | Email address saved locally for login convenience. |
| cached_batches | object | YES | NULL | - | Locally cached batch records used for faster loading. |
| cached_telemetry | object | YES | NULL | - | Locally cached sensor or telemetry readings. |
| temperature_threshold_settings | object | YES | NULL | - | Local temperature alert threshold settings. |
| alert_preferences | object | YES | NULL | - | Local notification and alert preference settings. |
| read_alert_ids | array | YES | NULL | - | List of alert IDs already viewed by the user. |
| cached_environmental_logs | object | YES | NULL | - | Locally cached environmental logs used for offline sync. |
