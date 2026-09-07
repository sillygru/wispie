import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'android_storage_service.dart';

final permissionServiceProvider =
    Provider<PermissionService>((ref) => PermissionService.instance);

class PermissionService {
  static final PermissionService instance = PermissionService._internal();

  PermissionService._internal();

  factory PermissionService() => instance;

  /// Checks whether storage permission is currently granted.
  ///
  /// On Android 10 and lower (SDK < 30), MANAGE_EXTERNAL_STORAGE does not exist,
  /// so standard storage permission (READ/WRITE_EXTERNAL_STORAGE) is checked.
  /// On Android 11 and higher (SDK >= 30), MANAGE_EXTERNAL_STORAGE is checked first,
  /// with a fallback to media/storage permissions.
  /// An unknown SDK (channel failure) falls back to the legacy storage check,
  /// since requesting MANAGE_EXTERNAL_STORAGE can never grant on API <= 29.
  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }

    final sdk = await AndroidStorageService.getSdkIntOrNull();
    if (sdk == null || sdk < 30) {
      return await Permission.storage.isGranted;
    }

    final statusManage = await Permission.manageExternalStorage.status;
    if (statusManage.isGranted) {
      return true;
    }

    final statusStorage = await Permission.storage.status;
    final statusAudio = await Permission.audio.status;
    return statusStorage.isGranted || statusAudio.isGranted;
  }

  /// Requests storage permission suitable for the current Android version.
  ///
  /// On Android 10 and lower (SDK < 30), requests standard storage permission.
  /// On Android 11 and higher (SDK >= 30), requests MANAGE_EXTERNAL_STORAGE.
  /// Unknown SDK falls back to the legacy request for the same reason as above.
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    final sdk = await AndroidStorageService.getSdkIntOrNull();
    if (sdk == null || sdk < 30) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }

    final statusManage = await Permission.manageExternalStorage.request();
    if (statusManage.isGranted) {
      return true;
    }

    final statusAudio = await Permission.audio.request();
    if (statusAudio.isGranted) {
      return true;
    }

    final statusStorage = await Permission.storage.request();
    return statusStorage.isGranted;
  }

  /// Checks if storage permission has been permanently denied.
  Future<bool> isStoragePermissionPermanentlyDenied() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final sdk = await AndroidStorageService.getSdkIntOrNull();
    if (sdk == null || sdk < 30) {
      return await Permission.storage.isPermanentlyDenied;
    }

    return await Permission.manageExternalStorage.isPermanentlyDenied;
  }

  /// Notification permission is required for the media playback foreground
  /// notification (android `POST_NOTIFICATIONS`, API 33+). Without it the
  /// service runs but no controls appear in the shade or lock screen.
  Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await AndroidStorageService.getSdkIntOrNull();
    // POST_NOTIFICATIONS was introduced in API 33. Below that, notifications
    // are granted at install time.
    if (sdk == null || sdk < 33) return true;
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await AndroidStorageService.getSdkIntOrNull();
    if (sdk == null || sdk < 33) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Ensures notification permission is granted where required. Returns true
  /// if notifications can be shown. Never throws. No-op on non-Android or
  /// API < 33, and on `permanentlyDenied` returns false without looping.
  Future<bool> ensureNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await AndroidStorageService.getSdkIntOrNull();
    if (sdk == null || sdk < 33) return true;
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final requested = await Permission.notification.request();
    return requested.isGranted;
  }
}
