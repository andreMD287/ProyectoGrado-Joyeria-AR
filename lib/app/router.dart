import 'package:go_router/go_router.dart';

import '../features/ar_experience/presentation/screens/try_on_screen.dart';
import '../features/catalog/presentation/screens/catalog_screen.dart';

/// Configuración de navegación de la aplicación.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const CatalogScreen(),
    ),
    GoRoute(
      path: '/try-on/:pieceId',
      builder: (context, state) =>
          TryOnScreen(pieceId: state.pathParameters['pieceId']!),
    ),
  ],
);
