# A3 — Inventario de dispositivos del equipo

**Frente:** A — Entorno de desarrollo · **Prioridad:** Alta · **Dependencias:** ninguna
**Estado:** 🟡 En progreso — 1 de 4 filas completa (André Landinez) · **Última actualización:** 2026-08-17

> Documento interno de trabajo. Objetivo: conocer la capacidad real de hardware del equipo (Grupo 7) antes del inicio de los sprints, y confirmar que se dispone de **al menos un dispositivo iOS y uno Android** aptos para desarrollo y pruebas continuas.

---

## 1. Requisitos de dispositivo (verdad de terreno)

- **Android:** versión mínima objetivo **Android 9.0 (API 28)**. **ARCore no es requisito**: la prueba virtual (aretes, pulseras, collares) usa cámara + ML Kit/MediaPipe y se validó funcionando en un dispositivo **sin** soporte ARCore (ver §3). ARCore solo haría falta para un visor de colocación en superficie que todavía no está implementado; si se retoma esa función, ahí sí aplicaría la lista oficial.
  - Lista oficial ARCore (solo relevante si se retoma el visor de superficie): https://developers.google.com/ar/devices
  - (Nota: la validación técnica previa usó `minSdk 24`, heredado del requisito de ARCore; el `minSdk` definitivo (28) se fijó en la tarea **A2**.)
- **iOS:** versión mínima objetivo **iOS 16.0** y soporte **ARKit** (dispositivo físico; ARKit no funciona en simulador).
  - Compatibilidad ARKit / dispositivos: https://developer.apple.com/documentation/arkit y https://support.apple.com/es-co/HT205434
- Se requiere **dispositivo físico** en ambas plataformas: AR no funciona en emulador/simulador.

---

## 2. Tabla de dispositivos

> Cada integrante completa su(s) fila(s). Marcar «Sí / No / ?» en las columnas de soporte y verificar contra las listas oficiales del §1.

| Integrante | Dispositivo (marca / modelo) | SO y versión | Chipset | ARCore | ARKit | Rol (dev / pruebas) | Plataforma que puede desarrollar |
|---|---|---|---|---|---|---|---|
| André Landinez | Samsung Galaxy A15 (SM-A155M) | Android 16 (API 36) | _(pendiente de confirmar — variante 4G: MediaTek Helio G99 / variante 5G: Exynos 1330)_ | **No** (confirmado: no está en la lista oficial; el visor de colocación en superficie no corre en este equipo) | — | Dev + pruebas | Android |
| _(pendiente)_ | | | | | | | |
| _(pendiente)_ | | | | | | | |
| _(pendiente)_ | | | | | | | |

### Equipos de cómputo (para compilación)

| Integrante | Equipo | SO | Chip (Intel / Apple Silicon) | Puede compilar Android | Puede compilar iOS |
|---|---|---|---|---|---|
| Valentina Carreño | MacBook Air | macOS | _(Apple Silicon?)_ | | En diagnóstico (tarea A1: `Flutter.h not found`) |
| _(equipo con Mac Mini)_ | Mac Mini | macOS | | | ✔ (entorno iOS confirmado en debug sobre iPhone físico) |
| _(pendiente)_ | | | | | |
| _(pendiente)_ | | | | | |

---

## 3. Datos ya conocidos (de la validación técnica previa)

Extraído del repositorio de validación técnica; **debe confirmarse** con los equipos reales:

- Existe **al menos un entorno iOS operativo** (Mac Mini): compila y ejecuta en **iPhone físico** en modo debug.
- Existe **al menos un dispositivo Android apto**: las tres categorías (muñeca, lóbulo, hombros) fueron **validadas en Android** en un Samsung Galaxy A15 **sin soporte ARCore** — confirma que ARCore no es requisito real para el dispositivo Android de pruebas (ver §1).
- **Valentina Carreño** trabaja sobre **MacBook Air** con un fallo de compilación iOS en diagnóstico (tarea A1).

> Estos puntos son indicios, no un inventario. Completar la tabla del §2 con datos verificados por cada integrante.

---

## 4. Verificación mínima antes de los sprints

- [x] Al menos **1 dispositivo Android** con Android ≥ 9.0 y cámara funcional (ARCore no es requisito — ver §1). Confirmado: Samsung Galaxy A15 (André Landinez).
- [ ] Al menos **1 dispositivo iOS** con soporte ARKit, iOS ≥ 16.0.
- [ ] Al menos **1 equipo capaz de compilar iOS** (macOS + Xcode) operativo.
- [ ] Los 4 integrantes saben en qué plataforma pueden desarrollar (enlaza con **A4** — verificación cruzada de entornos).

---

## 5. Criterio de cierre de la tarea (según TAREAS_PENDIENTES)

> «Existe una tabla de dispositivos disponibles, incorporada a este documento o al README.»
> Pendiente: que cada integrante complete su fila y se verifique contra las listas oficiales.
