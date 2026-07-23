import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'src/presentation/screens/engagement_detail_screen.dart';
import 'src/presentation/screens/gallery_screen.dart';
import 'src/presentation/screens/gallery_upload_screen.dart';
import 'src/presentation/screens/home_screen.dart';
import 'src/presentation/screens/mission_compose_screen.dart';
import 'src/presentation/screens/mission_screen.dart';
import 'src/presentation/screens/login_screen.dart';
import 'src/presentation/screens/my_page_screen.dart';
import 'src/presentation/screens/photo_viewer_screen.dart';
import 'src/presentation/screens/review_compose_screen.dart';
import 'src/presentation/screens/review_screen.dart';
import 'src/presentation/screens/tourist_spot_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException {
      // Browsing remains available while Firebase Auth is being configured.
    }
  }
  runApp(const B4yApp());
}

class B4yApp extends StatelessWidget {
  const B4yApp({super.key, this.initialLocation = '/'});

  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'B4Y',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF167A72),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F9F8),
          cardTheme: const CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        routerConfig: _createRouter(initialLocation: initialLocation),
      ),
    );
  }
}

GoRouter _createRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: true,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: 'my',
            builder: (context, state) => const MyPageScreen(),
          ),
          GoRoute(
            path: 'photos/:clusterId',
            builder: (context, state) => PhotoViewerScreen(
              clusterId: state.pathParameters['clusterId']!,
            ),
          ),
          GoRoute(
            path: 'missions',
            builder: (context, state) => MissionScreen(touristOnly: true),
          ),
          GoRoute(
            path: 'route-missions',
            builder: (context, state) => MissionScreen(
              routeOnly: true,
              initialRouteId: state.uri.queryParameters['routeId'],
            ),
          ),
          GoRoute(
            path: 'route-missions/:routeId/:missionId',
            builder: (context, state) => MissionDetailScreen(
              routeId: state.pathParameters['routeId']!,
              missionId: state.pathParameters['missionId']!,
            ),
          ),
          GoRoute(
            path: 'mission-groups/join',
            builder: (context, state) => MissionGroupJoinScreen(
              missionId: state.uri.queryParameters['missionId'] ?? '',
            ),
          ),
          GoRoute(
            path: 'gallery',
            builder: (context, state) => GalleryScreen(
              routeId: state.uri.queryParameters['routeId'],
              spotId: state.uri.queryParameters['spotId'],
              routeLabel: state.uri.queryParameters['routeLabel'],
            ),
            routes: [
              GoRoute(
                path: 'upload',
                builder: (context, state) => GalleryUploadScreen(
                  targetType: state.uri.queryParameters['targetType']!,
                  targetId: state.uri.queryParameters['targetId']!,
                  routeId: state.uri.queryParameters['routeId'] ?? '',
                  spotId: state.uri.queryParameters['spotId'] ?? '',
                  initialDirectionId:
                      state.uri.queryParameters['directionId'] ?? '',
                  initialStartStopId:
                      state.uri.queryParameters['startStopId'] ?? '',
                  initialEndStopId:
                      state.uri.queryParameters['endStopId'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'mission-compose',
            builder: (context, state) => MissionComposeScreen(
              spotId: '',
              touristOnly: true,
              initialRouteId: null,
              initialDirectionId: null,
              initialStartStopId: null,
              initialEndStopId: null,
            ),
          ),
          GoRoute(
            path: 'route-mission-compose',
            builder: (context, state) => MissionComposeScreen(
              spotId: '',
              routeOnly: true,
              initialRouteId: state.uri.queryParameters['routeId'],
              initialDirectionId: state.uri.queryParameters['directionId'],
              initialStartStopId: state.uri.queryParameters['startStopId'],
              initialEndStopId: state.uri.queryParameters['endStopId'],
            ),
          ),
          GoRoute(
            path: 'spots/:spotId',
            builder: (context, state) => TouristSpotDetailScreen(
              spotId: state.pathParameters['spotId']!,
            ),
            routes: [
              GoRoute(
                path: 'reviews',
                builder: (context, state) =>
                    ReviewScreen(spotId: state.pathParameters['spotId']!),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => ReviewComposeScreen(
                      spotId: state.pathParameters['spotId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':reviewId',
                    builder: (context, state) => ReviewDetailScreen(
                      spotId: state.pathParameters['spotId']!,
                      reviewId: state.pathParameters['reviewId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'missions',
                builder: (context, state) =>
                    MissionScreen(spotId: state.pathParameters['spotId']!),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => MissionComposeScreen(
                      spotId: state.pathParameters['spotId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':missionId',
                    builder: (context, state) => MissionDetailScreen(
                      spotId: state.pathParameters['spotId']!,
                      missionId: state.pathParameters['missionId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'gallery',
                builder: (context, state) =>
                    GalleryScreen(spotId: state.pathParameters['spotId']!),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
