// lib/utils/app_notifications.dart

import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';

// Enum to define different types of notifications
enum NotificationType { success, error, info }

void showAppNotification({
  required BuildContext context,
  required String message,
  required NotificationType type,
}) {
  // Determine color and icon based on the notification type
  Color color;
  IconData icon;

  switch (type) {
    case NotificationType.success:
      color = Colors.green.shade700;
      icon = Icons.check_circle_outline;
      break;
    case NotificationType.error:
      color = Colors.red.shade700;
      icon = Icons.error_outline;
      break;
    case NotificationType.info:
      color = Colors.blue.shade700;
      icon = Icons.info_outline;
      break;
  }

  // The main Flushbar configuration
  Flushbar(
    message: message,
    duration: const Duration(seconds: 3),
    flushbarPosition: FlushbarPosition.TOP,
    backgroundColor: color,
    icon: Icon(icon, size: 28.0, color: Colors.white),
    margin: const EdgeInsets.all(8),
    borderRadius: BorderRadius.circular(8),
  ).show(context);
}
