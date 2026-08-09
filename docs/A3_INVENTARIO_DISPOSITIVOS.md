# A3 — Inventario de dispositivos del equipo

**Frente:** A — Entorno de desarrollo · **Prioridad:** Alta · **Dependencias:** ninguna
**Estado:** Plantilla — pendiente de completar por cada integrante · **Última actualización:** 2026-08-09

> Documento interno de trabajo. Objetivo: conocer la capacidad real de hardware del equipo (Grupo 7) antes del inicio de los sprints, y confirmar que se dispone de **al menos un dispositivo iOS y uno Android** aptos para desarrollo y pruebas continuas.

---

## 1. Requisitos de dispositivo (verdad de terreno)

- **Android:** versión mínima objetivo **Android 9.0 (API 28)** y presencia en la lista oficial de dispositivos con soporte **ARCore**.
  - Lista oficial ARCore: https://developers.google.com/ar/devices
  - (Nota: la validación técnica previa usó `minSdk 24`, exigido por ARCore; la unificación del `minSdk` definitivo se resuelve en la tarea **A2**.)
- **iOS:** versión mínima objetivo **iOS 16.0** y soporte **ARKit** (dispositivo físico; ARKit no funciona en simulador).
  - Compatibilidad ARKit / dispositivos: https://developer.apple.com/documentation/arkit y https://support.apple.com/es-co/HT205434
- Se requiere **dispositivo físico** en ambas plataformas: AR no funciona en emulador/simulador.

---

## 2. Tabla de dispositivos

> Cada integrante completa su(s) fila(s). Marcar «Sí / No / ?» en las columnas de soporte y verificar contra las listas oficiales del §1.

| Integrante | Dispositivo (marca / modelo) | SO y versión | Chipset | ARCore | ARKit | Rol (dev / pruebas) | Plataforma que puede desarrollar |
|---|---|---|---|---|---|---|---|
| _(pendiente)_ | | | | | | | |
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
- Existe **al menos un dispositivo Android apto**: el tracking de muñeca (MediaPipe / `hand_landmarker`) fue **validado en Android**, lo que implica un dispositivo Android con ARCore y cámara funcionando.
- **Valentina Carreño** trabaja sobre **MacBook Air** con un fallo de compilación iOS en diagnóstico (tarea A1).

> Estos puntos son indicios, no un inventario. Completar la tabla del §2 con datos verificados por cada integrante.

---

## 4. Verificación mínima antes de los sprints

- [ ] Al menos **1 dispositivo Android** en la lista oficial ARCore, con Android ≥ 9.0.
- [ ] Al menos **1 dispositivo iOS** con soporte ARKit, iOS ≥ 16.0.
- [ ] Al menos **1 equipo capaz de compilar iOS** (macOS + Xcode) operativo.
- [ ] Los 4 integrantes saben en qué plataforma pueden desarrollar (enlaza con **A4** — verificación cruzada de entornos).

---

## 5. Criterio de cierre de la tarea (según TAREAS_PENDIENTES)

> «Existe una tabla de dispositivos disponibles, incorporada a este documento o al README.»
> Pendiente: que cada integrante complete su fila y se verifique contra las listas oficiales.
