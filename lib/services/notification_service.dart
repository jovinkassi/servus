// lib/services/notification_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification data model
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? jobId;
  final DateTime createdAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.jobId,
    required this.createdAt,
    this.read = false,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? '',
      jobId: data['jobId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }

  factory AppNotification.fromFCM(RemoteMessage message) {
    return AppNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      type: message.data['type'] ?? '',
      jobId: message.data['jobId'],
      createdAt: DateTime.now(),
      read: false,
    );
  }
}

/// Callback type for new notifications
typedef NotificationCallback = void Function(AppNotification notification);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // FCM instance (only used on mobile)
  FirebaseMessaging? _fcm;
  FlutterLocalNotificationsPlugin? _localNotifications;

  String? _currentUserId;
  String? _currentUserType;
  StreamSubscription? _notificationSubscription;

  // Callbacks for UI updates
  final List<NotificationCallback> _listeners = [];

  // Unread count
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (kIsWeb) {
      // WEB: Use Firestore-based notifications
      if (kDebugMode) {
        print('🌐 Web platform - using Firestore-based notifications');
      }
    } else {
      // MOBILE: Use Firebase Cloud Messaging
      if (kDebugMode) {
        print('📱 Mobile platform - using FCM notifications');
      }
      await _initializeFCM();
    }
  }

  /// Initialize FCM for mobile platforms
  Future<void> _initializeFCM() async {
    _fcm = FirebaseMessaging.instance;
    _localNotifications = FlutterLocalNotificationsPlugin();

    // Request permission
    NotificationSettings settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('FCM Permission status: ${settings.authorizationStatus}');
    }

    // Initialize local notifications for foreground display
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create high importance channel for Android
    const channel = AndroidNotificationChannel(
      'servus_notifications',
      'Servus Notifications',
      description: 'Notifications for job updates',
      importance: Importance.high,
    );

    await _localNotifications!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when user taps notification (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Check if app was opened from notification (app was terminated)
    RemoteMessage? initialMessage = await _fcm!.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }
  }

  /// Handle foreground FCM message (show local notification)
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('📩 Foreground FCM message: ${message.notification?.title}');
    }

    // Show local notification
    _localNotifications?.show(
      message.hashCode,
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'servus_notifications',
          'Servus Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['jobId'],
    );

    // Also notify in-app listeners
    final notification = AppNotification.fromFCM(message);
    for (final listener in _listeners) {
      listener(notification);
    }
  }

  /// Handle notification tap (app in background)
  void _handleNotificationOpen(RemoteMessage message) {
    if (kDebugMode) {
      print('🔔 Notification opened: ${message.data}');
    }
    // TODO: Navigate to relevant screen based on message.data
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('🔔 Local notification tapped: ${response.payload}');
    }
    // TODO: Navigate to relevant screen based on payload
  }

  /// Register user/worker for notifications
  Future<void> registerForNotifications({
    required String userId,
    required String userType,
  }) async {
    _currentUserId = userId;
    _currentUserType = userType;

    if (kIsWeb) {
      // WEB: Just listen to Firestore
      _startListeningForNotifications();
    } else {
      // MOBILE: Get FCM token and save to Firestore, plus listen to Firestore
      await _saveFCMToken(userId, userType);
      _startListeningForNotifications(); // Also listen for in-app display
    }

    if (kDebugMode) {
      print('Registered for notifications: $userType - $userId');
    }
  }

  /// Save FCM token to Firestore (for mobile)
  Future<void> _saveFCMToken(String userId, String userType) async {
    if (_fcm == null) return;

    try {
      String? token = await _fcm!.getToken();
      if (token != null) {
        final collection = userType == 'worker' ? 'workers' : 'customers';
        await _db.collection(collection).doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) {
          print('📱 FCM token saved for $userType: ${token.substring(0, 20)}...');
        }
      }

      // Listen for token refresh
      _fcm!.onTokenRefresh.listen((newToken) async {
        final collection = userType == 'worker' ? 'workers' : 'customers';
        await _db.collection(collection).doc(userId).update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) {
          print('📱 FCM token refreshed');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving FCM token: $e');
      }
    }
  }

  /// Add a listener for new notifications
  void addListener(NotificationCallback callback) {
    _listeners.add(callback);
  }

  /// Remove a listener
  void removeListener(NotificationCallback callback) {
    _listeners.remove(callback);
  }

  /// Start listening for new notifications from Firestore
  void _startListeningForNotifications() {
    if (_currentUserId == null || _currentUserType == null) return;

    // Cancel existing subscription
    _notificationSubscription?.cancel();

    final collection = _currentUserType == 'worker'
        ? 'worker_notifications'
        : 'customer_notifications';

    _notificationSubscription = _db
        .collection(collection)
        .doc(_currentUserId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      // Count unread
      _unreadCount = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['read'] != true;
      }).length;

      // Notify listeners about new notifications
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final notification = AppNotification.fromFirestore(change.doc);

          // Only notify for recent notifications (within last 30 seconds)
          final now = DateTime.now();
          if (now.difference(notification.createdAt).inSeconds < 30) {
            for (final listener in _listeners) {
              listener(notification);
            }
          }
        }
      }
    });
  }

  /// Get all notifications for current user
  Future<List<AppNotification>> getNotifications() async {
    if (_currentUserId == null || _currentUserType == null) return [];

    final collection = _currentUserType == 'worker'
        ? 'worker_notifications'
        : 'customer_notifications';

    final snapshot = await _db
        .collection(collection)
        .doc(_currentUserId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) => AppNotification.fromFirestore(doc))
        .toList();
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    if (_currentUserId == null || _currentUserType == null) return;

    final collection = _currentUserType == 'worker'
        ? 'worker_notifications'
        : 'customer_notifications';

    await _db
        .collection(collection)
        .doc(_currentUserId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_currentUserId == null || _currentUserType == null) return;

    final collection = _currentUserType == 'worker'
        ? 'worker_notifications'
        : 'customer_notifications';

    final snapshot = await _db
        .collection(collection)
        .doc(_currentUserId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();

    _unreadCount = 0;
  }

  /// Unregister from notifications (e.g., on logout)
  Future<void> unregisterFromNotifications() async {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _currentUserId = null;
    _currentUserType = null;
    _unreadCount = 0;
    _listeners.clear();
  }

  /// Show an in-app notification (for immediate feedback)
  void showLocalNotification({
    required String title,
    required String body,
    String? type,
    String? jobId,
  }) {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type ?? 'info',
      jobId: jobId,
      createdAt: DateTime.now(),
    );

    for (final listener in _listeners) {
      listener(notification);
    }
  }
}

/// Background message handler (required for mobile - must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('📩 Background FCM message: ${message.notification?.title}');
  }
  // Note: Can't show UI here, but can update local storage/database
}
