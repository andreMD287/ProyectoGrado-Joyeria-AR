import 'package:flutter/widgets.dart';

/// Construye [child] solo mientras su ruta es la de arriba del todo; tapada
/// por otra, deja [placeholder] en su lugar.
///
/// Es para los visores 3D en `WebView` (`ModelViewer`). Flutter mantiene vivas
/// las rutas tapadas, y la `WebView` seguía redibujándose debajo de la prueba
/// virtual (visto en el registro del Galaxy A15, 2026-11-08): le quitaba CPU y
/// GPU a la cámara, a la malla facial y al render de la joya. Al volver, el
/// visor se crea de nuevo y recarga el modelo.
class CurrentRouteOnly extends StatelessWidget {
  final Widget child;
  final Widget placeholder;

  const CurrentRouteOnly({
    super.key,
    required this.child,
    this.placeholder = const SizedBox.expand(),
  });

  @override
  Widget build(BuildContext context) =>
      ModalRoute.of(context)?.isCurrent ?? true ? child : placeholder;
}
