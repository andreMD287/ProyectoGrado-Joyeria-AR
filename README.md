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

Validado en dispositivo físico Android (sin ARCore): la prueba virtual detecta y ancla en tiempo real las tres categorías (muñeca, lóbulo, hombros) y las renderiza sobre la vista de cámara en vivo, con la detección corriendo en un isolate dedicado para no bloquear la UI. Pendiente: tracking en iOS (andamiaje listo, sin validar en iPhone), modelos GLB reales del catálogo (se usa un modelo de referencia mientras tanto) y el protocolo de precisión de detección en distintas condiciones. El detalle completo, tarea por tarea, está en [`docs/TAREAS_PENDIENTES.md`](docs/TAREAS_PENDIENTES.md).

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
| [`docs/SDD_2.3_ARQUITECTURA_DEL_SISTEMA.md`](docs/SDD_2.3_ARQUITECTURA_DEL_SISTEMA.md) | SDD §2.3: Flutter vs. arquitectura propia, patrones, tácticas y ADR. |
| [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) | Arquitectura técnica interna (carpetas, pipeline, adopción). |
| [`docs/TAREAS_PENDIENTES.md`](docs/TAREAS_PENDIENTES.md) | Tareas preparatorias (frentes A–E). |
| [`docs/D1_PIPELINE_DIGITALIZACION.md`](docs/D1_PIPELINE_DIGITALIZACION.md) | Pipeline de digitalización de piezas (GLB/PBR). |
| [`docs/D3_ESTRUCTURA_CATALOGO.md`](docs/D3_ESTRUCTURA_CATALOGO.md) | Estructura del catálogo y metadatos. |
