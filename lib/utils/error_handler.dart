import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logging_service.dart';

class ErrorHandler {
  /// Get user-friendly error message
  static String getUserMessage(dynamic error) {
    if (error is FirebaseException) {
      return _handleFirebaseError(error);
    } else if (error is SocketException) {
      return 'No internet connection. Please check your network.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else if (error is FormatException) {
      return 'Invalid data format. Please contact support.';
    } else if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return 'Something went wrong. Please try again later.';
  }

  /// Handle Firebase-specific errors
  static String _handleFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You don\'t have permission for this action.';
      case 'not-found':
        return 'Requested data not found.';
      case 'already-exists':
        return 'This item already exists.';
      case 'unauthenticated':
        return 'Please login to continue.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      case 'deadline-exceeded':
        return 'Request timed out. Please try again.';
      default:
        return 'Server error: ${error.message ?? "Please try again"}';
    }
  }

  /// Show error to user with SnackBar
  static void showError(
    BuildContext context,
    dynamic error, [
    StackTrace? stackTrace,
  ]) {
    LoggingService.error('Error occurred', error, stackTrace);

    final message = getUserMessage(error);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  /// Show success message
  static void showSuccess(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
