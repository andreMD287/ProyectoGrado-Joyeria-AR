# Joyería AR — Visualización virtual de joyería con Realidad Aumentada

Aplicación Flutter para probar virtualmente piezas de joyería (**aretes, pulseras y collares**) mediante Realidad Aumentada, anclándolas a puntos anatómicos detectados en tiempo real (lóbulo, muñeca, hombros).

Repositorio oficial del proyecto de grado (Grupo 7, 2026).

## Plataformas

- **Android** 9.0 (API 28)+ con soporte ARCore.
- **iOS** 16.0+ con soporte ARKit (dispositivo físico; la AR no funciona en simulador).

## Arquitectura

Clean Architecture *feature-first* + Riverpod (estado e inyección de dependencias). El diseño completo, con diagramas y decisiones, está en **[`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md)**.

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

En iOS, tras cambios en dependencias: `pod install` desde `ios/`.

## Estructura del repositorio

- `lib/`, `android/`, `ios/` — la aplicación.
- `assets/catalog/catalog.json` — catálogo de piezas (esquema en `docs/D3_ESTRUCTURA_CATALOGO.md`).
- `docs/` — arquitectura, pipeline de modelos 3D, catálogo, inventario de dispositivos y notas técnicas.
- `spikes/` — pruebas de concepto aisladas (p. ej. `B4-estabilizacion`, filtros de tracking).

## Documentación

| Documento | Contenido |
|---|---|
| [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) | Arquitectura de la aplicación. |
| [`docs/TAREAS_PENDIENTES.md`](docs/TAREAS_PENDIENTES.md) | Tareas preparatorias (frentes A–E). |
| [`docs/D1_PIPELINE_DIGITALIZACION.md`](docs/D1_PIPELINE_DIGITALIZACION.md) | Pipeline de digitalización de piezas (GLB/PBR). |
| [`docs/D3_ESTRUCTURA_CATALOGO.md`](docs/D3_ESTRUCTURA_CATALOGO.md) | Estructura del catálogo y metadatos. |
