import 'alert_notification_store.dart';
import 'batch_store.dart';
import 'environmental_log_store.dart';
import 'monitoring_store.dart';
import 'temperature_settings_store.dart';

void resetAccountScopedStores() {
  BatchStore.instance.clear();
  TemperatureSettingsStore.instance.resetForAccountSwitch();
  MonitoringStore.instance.resetForAccountSwitch();
  AlertNotificationStore.instance.resetForAccountSwitch();
  EnvironmentalLogStore.instance.resetForAccountSwitch();
}
