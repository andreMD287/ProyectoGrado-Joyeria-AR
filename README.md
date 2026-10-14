# Joyería AR — Visualización virtual de joyería con Realidad Aumentada

Aplicación Flutter para probar virtualmente piezas de joyería (**aretes, pulseras y collares**) mediante Realidad Aumentada, anclándolas a puntos anatómicos detectados en tiempo real (lóbulo, muñeca, hombros).

Repositorio oficial del proyecto de grado (Grupo 7, 2026).

## Equipo

- Valentina Carreño
- Juan Garzón
- José Ontiveros
- André Landinez

## Plataformas

- **Android** 9.0 (API 28)+. La prueba virtual (aretes, pulseras, collares) usa cámara + ML Kit/MediaPipe y **no requiere ARCore**; corre en cualquier dispositivo Android con cámara, tenga o no soporte ARCore. ARCore solo sería necesario para un visor de colocación en superficie aún no implementado.
- **iOS** 16.0+ (dispositivo físico; el tracking por cámara no corre en simulador).

## Estado actual

Validado en dispositivo físico Android (sin ARCore): la prueba virtual detecta y ancla en tiempo real las tres categorías (muñeca, lóbulo, hombros), con la detección corriendo en un isolate dedicado para no bloquear la UI. El render ya no es un *sprite* 2D sobre la cámara: es una escena 3D con cámara en perspectiva propia y buffer de profundidad (ADR-16), de donde sale la **oclusión** de la pieza por la extremidad que la lleva (ADR-17).

Pendiente: la oclusión solo funciona en **pulseras** —aretes y collares aún se dibujan siempre por delante—, el ajuste del aro sobre el brazo no se da por bueno y sus constantes antropométricas están calibradas sobre una sola persona; el motor de render solo está verificado en Android; falta tracking en iOS (andamiaje listo, sin validar en iPhone), los modelos GLB reales del catálogo y el protocolo de precisión de detección. El estado de la oclusión, con alternativas y estimaciones, está en [`docs/B6_OCLUSION_ESTADO_Y_ALTERNATIVAS.md`](docs/B6_OCLUSION_ESTADO_Y_ALTERNATIVAS.md); el detalle tarea por tarea, en [`docs/TAREAS_PENDIENTES.md`](docs/TAREAS_PENDIENTES.md).

## Arquitectura

Clean Architecture *feature-first* + estilo microkernel en el pipeline de prueba virtual + Riverpod (estado e inyección de dependencias). El diseño completo, con diagramas y decisiones, está en **[`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md)**; la justificación académica (Flutter vs. aplicación, microkernel, ADR) en **[`docs/SDD_2.3_ARQUITECTURA_DEL_SISTEMA.md`](docs/SDD_2.3_ARQUITECTURA_DEL_SISTEMA.md)**.

```
lib/
├── app/         # arranque, tema y navegación (go_router)
├── core/        # transversal: cámara, permisos, filtros, isolate, DI
└── features/    # catalog · tracking · ar_experience (domain / data / presentation)
```

## Puesta en marcha

```bash
flutter pub get
flutter run --debug        # dispositivo físico (la AR no corre en emulador/simulador)
```

**Android — requisito del build nativo.** La prueba virtual renderiza con `three_js`, que depende de `flutter_angle` y compila ANGLE con CMake y el NDK. Sin esa versión exacta el build falla con `[CXX1300] CMake '3.31.4' was not found in SDK, PATH, or by cmake.dir property`. Se instala una sola vez:

```bash
"$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --install "cmake;3.31.4"
```

En iOS, tras cambios en dependencias: `pod install` desde `ios/`.

## Estructura del repositorio

- `lib/`, `android/`, `ios/` — la aplicación.
- `assets/catalog/catalog.json` — catálogo de piezas (esquema en `docs/D3_ESTRUCTURA_CATALOGO.md`).
- `docs/` — arquitectura, pipeline de modelos 3D, catálogo, inventario de dispositivos y notas técnicas.
- `spikes/` — pruebas de concepto aisladas (p. ej. `B4-estabilizacion`, filtros de tracking).

## Documentación

| Documento | Contenido |
|---|---|
| [`docs/SDD_2.3_ARQUITECTURA_DEL_SISTEMA.md`](docs/SDD_2.3_ARQUITECTURA_DEL_SISTEMA.md) | SDD §2.3: Flutter vs. arquitectura propia, patrones, tácticas y ADR. |
| [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) | Arquitectura técnica interna (carpetas, pipeline, adopción). |
| [`docs/B6_OCLUSION_ESTADO_Y_ALTERNATIVAS.md`](docs/B6_OCLUSION_ESTADO_Y_ALTERNATIVAS.md) | Oclusión: alternativas evaluadas, estado actual y trabajo futuro estimado. |
| [`docs/TAREAS_PENDIENTES.md`](docs/TAREAS_PENDIENTES.md) | Tareas preparatorias (frentes A–E). |
| [`docs/D1_PIPELINE_DIGITALIZACION.md`](docs/D1_PIPELINE_DIGITALIZACION.md) | Pipeline de digitalización de piezas (GLB/PBR). |
| [`docs/D3_ESTRUCTURA_CATALOGO.md`](docs/D3_ESTRUCTURA_CATALOGO.md) | Estructura del catálogo y metadatos. |
