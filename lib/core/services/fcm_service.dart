// lib/core/services/fcm_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart'; // API 서비스 임포트

// 백그라운드 메시지 핸들러 (앱이 꺼져있을 때)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("백그라운드에서 푸시 알림 수신: ${message.messageId}");
}

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // 1. FCM 초기화 함수
  Future<void> init() async {
    // 권한 요청 (iOS & Android 13+)
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // FCM 토큰 가져와서 서버로 전송
    final fcmToken = await _firebaseMessaging.getToken();
    if (fcmToken != null) {
      print("FCM Token: $fcmToken");
      await _sendTokenToServer(fcmToken);
    }

    // 토큰이 갱신될 때마다 서버에 다시 전송
    _firebaseMessaging.onTokenRefresh.listen(_sendTokenToServer);

    // 포그라운드 알림 처리 설정
    await _setupForegroundNotifications();

    // 메시지 리스너 설정
    _setupMessageListeners();
  }

  // 2. FCM 토큰을 Spring Boot 서버로 보내는 함수
  Future<void> _sendTokenToServer(String token) async {
    try {
      // Spring Boot에 만들어 둘 API 엔드포인트
      await ApiService.post('/api/users/save-fcm-token', {'fcmToken': token});
      print("FCM 토큰을 서버에 성공적으로 저장했습니다.");
    } catch (e) {
      print("FCM 토큰 서버 저장 실패: $e");
    }
  }

  // 3. 포그라운드(앱 실행 중) 알림 설정
  Future<void> _setupForegroundNotifications() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // 채널 ID
      '중요 알림', // 채널 이름
      description: '중요한 알림을 위한 채널입니다.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // 4. 메시지 수신 리스너 설정
  void _setupMessageListeners() {
    // 앱이 포그라운드에 있을 때
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              '중요 알림',
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });

    // 앱이 백그라운드에 있을 때 사용자가 알림을 탭한 경우
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('알림을 탭하여 앱을 열었습니다: ${message.data}');
      // 예: `message.data['screen']` 값에 따라 특정 화면으로 이동
    });

    // 앱이 완전히 종료된 상태에서 알림을 탭하여 실행된 경우
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}