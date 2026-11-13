import 'package:go_router/go_router.dart';

import '../features/ar_experience/presentation/screens/try_on_prepare_screen.dart';
import '../features/ar_experience/presentation/screens/try_on_screen.dart';
import '../features/catalog/presentation/screens/catalog_screen.dart';
import '../features/catalog/presentation/screens/home_screen.dart';
import '../features/jewelry_detail/presentation/screens/jewelry_3d_screen.dart';
import '../features/jewelry_detail/presentation/screens/jewelry_detail_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';

/// Configuración de navegación de la aplicación.
final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),

    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),

    GoRoute(
      path: '/catalog',
      builder: (context, state) => CatalogScreen(
        initialCategory: state.uri.queryParameters['category'],
        initialSearch: state.uri.queryParameters['search'],
      ),
    ),

    GoRoute(
      path: '/piece/:pieceId',
      builder: (context, state) =>
          JewelryDetailScreen(pieceId: state.pathParameters['pieceId']!),
    ),

    GoRoute(
      path: '/piece/:pieceId/3d',
      builder: (context, state) =>
          Jewelry3dScreen(pieceId: state.pathParameters['pieceId']!),
    ),

    GoRoute(
      path: '/try-on/:pieceId/prepare',
      builder: (context, state) =>
          TryOnPrepareScreen(pieceId: state.pathParameters['pieceId']!),
    ),

    GoRoute(
      path: '/try-on/:pieceId',
      builder: (context, state) =>
          TryOnScreen(pieceId: state.pathParameters['pieceId']!),
    ),
  ],
);
