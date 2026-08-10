# B4 — Spike: estabilización del tracking (One Euro vs. Kalman)

**Frente:** B — Spikes de investigación · **Prioridad:** Media · **Alimenta:** C3 (integración del filtro en Android)
**Tipo:** Técnica (prueba de concepto ejecutable) · **Estado:** Comparación resuelta con recomendación · **Última actualización:** 2026-08-09

> Los landmarks del tracking presentan variación (*jitter*) entre fotogramas. Este spike compara un **One Euro Filter** frente a un **Kalman de velocidad constante** sobre las coordenadas del landmark de anclaje (p. ej. la muñeca / WRIST del MVP), y deja definidos los parámetros iniciales.

---

## 1. Qué contiene

Paquete Dart **puro y sin dependencias externas** (corre solo con el SDK):

```
spikes/B4-estabilizacion/
├── lib/
│   ├── one_euro_filter.dart      # One Euro Filter 1D (Casiez et al., CHI 2012)
│   ├── kalman_filter.dart        # Kalman 1D, modelo de velocidad constante
│   └── landmark_stabilizer.dart  # Envoltorios (x,y,z) + interfaz común intercambiable
└── bin/
    └── b4_compare.dart           # Banco de comparación ejecutable + chequeos
```

### Cómo reproducir
```bash
cd spikes/B4-estabilizacion
dart pub get          # sin dependencias externas → resuelve offline
dart run bin/b4_compare.dart
```

El banco genera señales sintéticas a **10 FPS** (la tasa de detección del MVP), con ruido gaussiano σ=0.01 sobre coordenadas normalizadas y **semilla fija** (reproducible), en tres escenarios: mano quieta, movimiento lento (seno 0.25 Hz) y cambio brusco (escalón). Los chequeos hacen fallar el proceso (exit ≠ 0) si algún filtro no cumple lo esperado.

---

## 2. Resultados (ejecución reproducible, semilla 42)

**Escenario 1 — mano quieta** (jitter = RMS de la diferencia entre frames; menor es mejor):

| Métrica | Crudo | One Euro | Kalman |
|---|---|---|---|
| jitter RMS | 0.01385 | 0.00412 (**−70.3%**) | 0.00367 (**−73.5%**) |
| desv. residual vs. verdad | 0.00948 | 0.00449 | 0.00446 |

**Escenario 2 — movimiento lento** (seno 0.25 Hz, amplitud 0.2):

| Métrica | Crudo | One Euro | Kalman |
|---|---|---|---|
| RMSE vs. verdad (lag+ruido) | 0.01136 | **0.03336** | 0.04381 |
| jitter RMS | 0.02739 | 0.02151 | 0.02420 |

**Escenario 3 — cambio brusco** (0.4 → 0.6):

| Métrica | Crudo | One Euro | Kalman |
|---|---|---|---|
| latencia hasta 90% del escalón | — | **0.4 s** (4 frames) | **0.4 s** (4 frames) |
| jitter RMS | 0.01982 | 0.00802 | 0.00767 |

---

## 3. Análisis

- **En reposo**, ambos filtros reducen el jitter de forma comparable (~70–74%). La ventaja de Kalman aquí es **marginal** (0.00367 vs 0.00412).
- **En movimiento continuo**, One Euro **sigue la señal con notablemente menos lag** que Kalman (RMSE 0.033 vs 0.044, ~33% mejor). Es la propiedad que importa para una pieza que debe seguir una muñeca en movimiento: su frecuencia de corte adaptativa sube con la velocidad y reduce el retardo. El Kalman de velocidad constante arrastra más al cambiar de dirección.
- **Ante un cambio brusco**, ambos convergen igual de rápido (0.4 s).
- **Detalle metodológico:** con ruido bajo sobre una señal en movimiento, *cualquier* filtro sube el RMSE-vs-verdad porque introduce algo de lag; eso no es un defecto sino el balance jitter↔latencia que hay que ajustar. Por eso la métrica decisiva en movimiento es el **lag comparado entre filtros**, no el RMSE absoluto contra el crudo.

---

## 4. Recomendación

**Usar One Euro Filter** como estabilizador del landmark de anclaje, por:

1. Reducción de jitter en reposo prácticamente igual a la del Kalman.
2. **Menor lag en movimiento** — clave para que la joya no "se arrastre" detrás de la muñeca.
3. Igual latencia ante cambios bruscos.
4. **Menos parámetros y más intuitivos** (`minCutoff`, `beta`) frente al ajuste de `Q`/`R` del Kalman, que es sensible a la escala de las coordenadas.
5. Es el estándar de facto para estabilizar tracking interactivo (fue diseñado exactamente para este caso).

Reservar el **Kalman** para si más adelante se necesita, además del suavizado, una **estimación de velocidad** (p. ej. predicción del anclaje para compensar latencia de render).

### Parámetros iniciales (coordenadas normalizadas, ~10 FPS)

| Filtro | Parámetro | Valor inicial | Ajuste |
|---|---|---|---|
| One Euro | `minCutoff` | **1.0 Hz** | Si tiembla en reposo, bajar a 0.5–1.0. |
| One Euro | `beta` | **0.02** | Si va con lag al mover, subir a 0.03–0.05. |
| One Euro | `dCutoff` | **1.0 Hz** | Normalmente no se toca. |

> La coordenada **z (profundidad)** de MediaPipe es más ruidosa que x,y; se puede usar para z un `minCutoff` algo menor (más suavizado). Los valores definitivos deben afinarse **en dispositivo** con la mano real (ver §6).

---

## 5. Integración en Android (tarea C3)

`landmark_stabilizer.dart` expone la interfaz `LandmarkStabilizer` para intercambiar el filtro sin tocar el anclaje. Enganche sugerido en `ARHandScreen._onCameraFrame` del MVP (o en el proyecto real), aplicando el filtro al landmark 0 (WRIST) antes de usarlo como ancla:

```dart
// Campo del State:
final LandmarkStabilizer _stabilizer =
    OneEuroStabilizer(minCutoff: 1.0, beta: 0.02, dCutoff: 1.0);

// Dentro de _onCameraFrame, tras obtener el resultado de detect():
final wrist = hands.isNotEmpty ? hands[0].landmarks[0] : null;
if (wrist != null) {
  final t = nowMs / 1000.0; // reloj monótono en segundos
  final s = _stabilizer.filter(Vec3(wrist.x, wrist.y, wrist.z), t);
  // usar s.x, s.y, s.z como punto de anclaje estabilizado
}

// Al perder la mano (hands vacío por varios frames), llamar _stabilizer.reset()
// para que no "arrastre" desde la última posición al reaparecer.
```

---

## 6. Criterio de cierre (según TAREAS_PENDIENTES)

> «Existe una comparación práctica entre ambos filtros y una recomendación con parámetros iniciales definidos.» — **Cubierto.**

**Pendiente de validación en dispositivo (C3):** este banco usa señales sintéticas; los parámetros son un punto de partida. Falta confirmar en un Android real, con el tracking de muñeca del MVP como banco de pruebas, que el anclaje deja de temblar sin lag perceptible.
