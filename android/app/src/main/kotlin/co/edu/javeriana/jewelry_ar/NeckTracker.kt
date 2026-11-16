package co.edu.javeriana.jewelry_ar

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.ByteBufferExtractor
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.imagesegmenter.ImageSegmenter
import io.flutter.FlutterInjector
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Seguimiento del cuello para collares, con MediaPipe (Android).
 *
 * ML Kit Pose solo da hombros, orejas y nariz: el cuello había que deducirlo
 * con proporciones fijas, y eso fallaba distinto en cada pose. Aquí se mide.
 *
 * - **Face Landmarker, en CPU, en cada frame.** Da el mentón y el ancho de la
 *   cara, que es lo que lleva el seguimiento rápido. Medido en el Galaxy A15
 *   (2026-11-04): 15–60 ms en CPU contra ~175 ms en GPU.
 * - **Segmentación multiclase, en GPU, a su ritmo (~4 Hz).** Separa piel del
 *   cuerpo, cara y ropa, y de ahí sale la forma real del cuello: dónde se une
 *   con la ropa a cada lado y dónde acaba el escote. Medido: ~250 ms en GPU,
 *   ~400 en CPU, sin cambio al achicar la imagen. Es demasiado lenta para cada
 *   frame, pero la forma del cuello respecto a la cara cambia poco.
 *
 * Las medidas del cuello se devuelven junto con el mentón y el ancho de cara
 * del frame en que se tomaron, para que Dart las traslade a la cara actual.
 *
 * Todo sale normalizado al frame **ya rotado a vertical y sin espejar**; el
 * espejo de la cámara frontal lo aplica Dart, como con el resto de detectores.
 *
 * **En tubería.** `process` deja el frame y responde enseguida con el último
 * resultado; un hilo procesa siempre el frame más reciente y descarta los que
 * se acumulan. Antes cada frame esperaba su respuesta antes de mandar el
 * siguiente y la cara iba a 6–7 Hz aunque solo tarda 40–60 ms (medido en el
 * Galaxy A15, 2026-11-05).
 *
 * **Modelos precargados.** Se crean al abrir la app y no se cierran al salir de
 * la prueba virtual: el segmentador en GPU tardaba ~20 s en arrancar y, como se
 * cerraba, la espera se repetía en cada entrada. Mientras la GPU no está lista
 * se segmenta en CPU.
 *
 * **Modo cabeza, para aretes** (`start` con `mode: "head"`). Usa la misma malla
 * facial pero no segmenta: entrega más puntos de la cara ([HEAD_POINTS]) y la
 * matriz de transformación facial, de la que Dart saca la rotación de la
 * cabeza para colgar los aretes y su oclusión. Cada resultado se publica por
 * el `EventChannel` `jewelry_ar/head_results` apenas está, en vez de esperar
 * al siguiente `process` (ver `PushesResults` en Dart).
 *
 * La malla se queda en CPU también para aretes. En la GPU, sin segmentación
 * compartiéndola, tardó 120–130 ms por frame contra ~50 en CPU, y la cabeza
 * bajó de ~15 a ~7 actualizaciones por segundo (Galaxy A15, 2026-11-08).
 */
class NeckTracker(private val context: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        private const val TAG = "NeckTracker"
        // Assets de Flutter (`assets/mediapipe/`), compartidos con iOS. Dentro
        // del APK quedan bajo `flutter_assets/`; la clave la da el loader.
        private val FACE_MODEL = flutterAsset("face_landmarker.task")
        private val SEG_MODEL = flutterAsset("selfie_multiclass_256x256.tflite")

        private fun flutterAsset(name: String): String =
            FlutterInjector.instance().flutterLoader()
                .getLookupKeyForAsset("assets/mediapipe/$name")

        // Índices de la malla facial.
        private const val CHIN = 152
        private const val CHEEK_LEFT = 234
        private const val CHEEK_RIGHT = 454
        private const val NOSE = 1
        private val FACE_POINTS = intArrayOf(CHIN, CHEEK_LEFT, CHEEK_RIGHT, NOSE)

        /**
         * Puntos del modo cabeza, **en este orden**: tiene que coincidir con
         * `headMeshPoints` en `head_detector_datasource.dart`.
         */
        private val HEAD_POINTS = intArrayOf(
            234, 454, 10, 152, 1, 2, 33, 263, 93, 323, 132, 361, 58, 288,
        )

        /** Lado de las teselas de la conversión a ARGB, en píxeles (par). */
        private const val TILE = 32

        /** Ancho al que se reduce el frame para segmentar: el modelo es de 256. */
        private const val SEG_WIDTH = 240

        /** Pasado este tiempo, una medida del cuello ya no describe la pose. */
        private const val NECK_MAX_AGE_MS = 1500L

        /** Pasado este tiempo, el último resultado de la cara ya no se entrega. */
        private const val RESULT_MAX_AGE_MS = 500L
    }

    private class Frame(val nv: ByteArray, val w: Int, val h: Int, val stride: Int, val rotation: Int)

    private val faceExec = Executors.newSingleThreadExecutor { r -> Thread(r, "neck-face") }

    // El delegado GPU exige crear y usar el segmentador en el mismo hilo. Baja
    // prioridad: su arranque compila para la GPU y no debe trabar la app.
    private val segExec = Executors.newSingleThreadExecutor { r ->
        Thread(r, "neck-seg-gpu").apply { priority = Thread.MIN_PRIORITY }
    }
    private val segCpuExec = Executors.newSingleThreadExecutor { r -> Thread(r, "neck-seg-cpu") }

    private var face: FaceLandmarker? = null

    /** Por donde se publican los resultados del modo cabeza. */
    @Volatile private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())
    private var segmenter: ImageSegmenter? = null
    private var cpuSegmenter: ImageSegmenter? = null
    @Volatile private var gpuReady = false
    @Volatile private var gpuFailed = false
    private val segBusy = AtomicBoolean(false)

    // Tubería de la cara: el frame más reciente pendiente y el último resultado.
    private val pendingLock = Any()
    private var pending: Frame? = null
    private val faceBusy = AtomicBoolean(false)
    @Volatile private var latest: Map<String, Any>? = null
    @Volatile private var latestAt = 0L
    private var seq = 0L

    init {
        faceExec.execute { ensureFace() }
        segExec.execute { ensureGpuSegmenter() }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    @Volatile private var active = false

    /** Aretes: sin segmentación, con más puntos y la pose de la cabeza. */
    @Volatile private var headMode = false
    @Volatile private var neck: Map<String, Any>? = null
    @Volatile private var neckAt = 0L

    // Última forma aceptada y la candidata que la contradice, en coordenadas
    // relativas a la cara: (centro x, centro y, ancho) en anchos de cara.
    private var accepted: DoubleArray? = null
    private var candidate: DoubleArray? = null
    private var lastTs = 0L

    // Estadísticas para el registro (cada 5 s).
    private var statsStart = 0L
    private var faceFrames = 0
    private var faceMsSum = 0L
    private var convMsSum = 0L
    @Volatile private var segFrames = 0
    @Volatile private var segMsSum = 0L
    @Volatile private var segOk = 0
    private var lastDebugSave = 0L

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                headMode = call.argument<String>("mode") == "head"
                active = true
                neck = null
                latest = null
                accepted = null
                candidate = null
                // No-ops si ya se precargaron al abrir la app.
                faceExec.execute { ensureFace() }
                segExec.execute { ensureGpuSegmenter() }
                result.success(null)
            }
            "process" -> {
                val bytes = call.argument<ByteArray>("bytes")
                val w = call.argument<Int>("width") ?: 0
                val h = call.argument<Int>("height") ?: 0
                val stride = call.argument<Int>("stride") ?: w
                val rotation = call.argument<Int>("rotation") ?: 0
                if (bytes == null || w <= 0 || h <= 0) {
                    result.success(null)
                    return
                }
                synchronized(pendingLock) { pending = Frame(bytes, w, h, stride, rotation) }
                if (faceBusy.compareAndSet(false, true)) faceExec.execute { drain() }
                // Con aretes el resultado sale por el `EventChannel`.
                if (headMode && sink != null) {
                    result.success(null)
                    return
                }
                val out = latest
                val fresh = SystemClock.uptimeMillis() - latestAt < RESULT_MAX_AGE_MS
                result.success(if (out != null && fresh) out else null)
            }
            "stop" -> {
                // Los modelos se quedan cargados para la próxima entrada.
                active = false
                neck = null
                latest = null
                synchronized(pendingLock) { pending = null }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureFace(): FaceLandmarker? {
        face?.let { return it }
        return try {
            FaceLandmarker.createFromOptions(
                context,
                FaceLandmarker.FaceLandmarkerOptions.builder()
                    .setBaseOptions(
                        BaseOptions.builder()
                            .setModelAssetPath(FACE_MODEL)
                            .setDelegate(Delegate.CPU)
                            .build(),
                    )
                    // VIDEO sigue la cara entre frames en vez de buscarla en
                    // cada uno: más rápido y más estable.
                    .setRunningMode(RunningMode.VIDEO)
                    .setNumFaces(1)
                    // La pose de la cabeza para los aretes. Es un ajuste de la
                    // malla ya calculada al modelo canónico: barato, y el
                    // landmarker es el mismo para los dos modos.
                    .setOutputFacialTransformationMatrixes(true)
                    .build(),
            ).also { face = it }
        } catch (e: Throwable) {
            Log.e(TAG, "no se pudo crear el Face Landmarker", e)
            null
        }
    }

    private fun createSegmenter(delegate: Delegate): ImageSegmenter =
        ImageSegmenter.createFromOptions(
            context,
            ImageSegmenter.ImageSegmenterOptions.builder()
                .setBaseOptions(
                    BaseOptions.builder()
                        .setModelAssetPath(SEG_MODEL)
                        .setDelegate(delegate)
                        .build(),
                )
                .setRunningMode(RunningMode.IMAGE)
                .setOutputCategoryMask(true)
                .setOutputConfidenceMasks(false)
                .build(),
        )

    /** Solo en [segExec]. */
    private fun ensureGpuSegmenter() {
        if (segmenter != null || gpuFailed) return
        val t0 = SystemClock.uptimeMillis()
        try {
            segmenter = createSegmenter(Delegate.GPU)
            gpuReady = true
            Log.i(TAG, "segmentador GPU listo en ${SystemClock.uptimeMillis() - t0} ms")
            // Ya no hace falta el de respaldo.
            segCpuExec.execute {
                cpuSegmenter?.close()
                cpuSegmenter = null
            }
        } catch (e: Throwable) {
            gpuFailed = true
            Log.w(TAG, "segmentador GPU no disponible, se usa CPU: $e")
        }
    }

    /** Solo en [segCpuExec]. */
    private fun ensureCpuSegmenter(): ImageSegmenter? {
        cpuSegmenter?.let { return it }
        return try {
            createSegmenter(Delegate.CPU).also { cpuSegmenter = it }
        } catch (e: Throwable) {
            Log.e(TAG, "no se pudo crear el segmentador en CPU", e)
            null
        }
    }

    /** Procesa siempre el frame más reciente hasta que no quede ninguno. */
    private fun drain() {
        while (true) {
            val f = synchronized(pendingLock) { pending.also { pending = null } }
            if (f == null) {
                faceBusy.set(false)
                // Pudo llegar uno justo entre la lectura y soltar el turno.
                val queda = synchronized(pendingLock) { pending != null }
                if (queda && faceBusy.compareAndSet(false, true)) continue
                return
            }
            val out = try {
                if (active) process(f.nv, f.w, f.h, f.stride, f.rotation) else null
            } catch (e: Throwable) {
                Log.w(TAG, "fallo al procesar el frame", e)
                null
            }
            if (out != null && active) {
                seq++
                val withSeq = out + ("seq" to seq)
                latest = withSeq
                latestAt = SystemClock.uptimeMillis()
                if (headMode) {
                    main.post { if (active && headMode) sink?.success(withSeq) }
                }
            }
        }
    }

    private fun process(nv: ByteArray, w: Int, h: Int, stride: Int, rotation: Int): Map<String, Any> {
        val landmarker = ensureFace() ?: return mapOf("face" to false)
        val t0 = SystemClock.uptimeMillis()
        val frame = toUprightBitmap(nv, w, h, stride, rotation)
        val tConv = SystemClock.uptimeMillis()

        var ts = SystemClock.uptimeMillis()
        if (ts <= lastTs) ts = lastTs + 1
        lastTs = ts
        val result = landmarker.detectForVideo(BitmapImageBuilder(frame).build(), ts)
        val lms = result.faceLandmarks().firstOrNull()
        countFace(tConv - t0, SystemClock.uptimeMillis() - tConv)
        if (lms == null) return mapOf("face" to false)

        if (headMode) {
            val head = DoubleArray(HEAD_POINTS.size * 3)
            for ((k, i) in HEAD_POINTS.withIndex()) {
                head[k * 3] = lms[i].x().toDouble()
                head[k * 3 + 1] = lms[i].y().toDouble()
                head[k * 3 + 2] = lms[i].z().toDouble()
            }
            val out = HashMap<String, Any>()
            out["face"] = true
            out["points"] = head
            // 4×4 tal cual la da MediaPipe (por columnas); Dart extrae la
            // rotación y comprueba la convención.
            val matrix = result.facialTransformationMatrixes()
                .orElse(null)?.firstOrNull()
            if (matrix != null && matrix.size == 16) {
                out["matrix"] = DoubleArray(16) { matrix[it].toDouble() }
            }
            return out
        }

        val points = DoubleArray(FACE_POINTS.size * 3)
        for ((k, i) in FACE_POINTS.withIndex()) {
            points[k * 3] = lms[i].x().toDouble()
            points[k * 3 + 1] = lms[i].y().toDouble()
            points[k * 3 + 2] = lms[i].z().toDouble()
        }
        val aspect = frame.height.toDouble() / frame.width
        val faceWidth = faceWidth(points, aspect)

        // La segmentación va por su lado: si está libre se le pasa este frame.
        if (segBusy.compareAndSet(false, true)) {
            val small = Bitmap.createScaledBitmap(
                frame, SEG_WIDTH, frame.height * SEG_WIDTH / frame.width, true,
            )
            val chinX = points[0]
            val chinY = points[1]
            val gpu = gpuReady
            val exec = if (gpu) segExec else segCpuExec
            exec.execute {
                try {
                    val seg = if (gpu) segmenter else ensureCpuSegmenter()
                    if (active && seg != null) measureNeck(seg, small, chinX, chinY, faceWidth)
                } catch (e: Throwable) {
                    Log.w(TAG, "fallo al segmentar", e)
                } finally {
                    segBusy.set(false)
                }
            }
        }

        val out = HashMap<String, Any>()
        out["face"] = true
        out["points"] = points
        out["faceWidth"] = faceWidth
        val n = neck
        if (n != null && SystemClock.uptimeMillis() - neckAt < NECK_MAX_AGE_MS) out["neck"] = n
        return out
    }

    /**
     * Ancho de la cara de mejilla a mejilla, **en 3D** y en fracciones del ancho
     * del frame. La `z` de la malla va en la misma escala que `x`, así que el
     * ancho no se encoge al girar la cabeza.
     */
    private fun faceWidth(p: DoubleArray, aspect: Double): Double {
        val dx = p[6] - p[3]
        val dy = (p[7] - p[4]) * aspect
        val dz = p[8] - p[5]
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    private fun measureNeck(
        seg: ImageSegmenter, small: Bitmap, chinX: Double, chinY: Double, faceWidth: Double,
    ) {
        val t0 = SystemClock.uptimeMillis()
        val result = seg.segment(BitmapImageBuilder(small).build())
        val maskImage = result.categoryMask().orElse(null) ?: return
        val mw = maskImage.width
        val mh = maskImage.height
        val mask = ByteArray(mw * mh)
        val buffer = ByteBufferExtractor.extract(maskImage)
        buffer.rewind()
        buffer.get(mask)
        maskImage.close()

        val measure = NeckMeasure.measure(
            mask, mw, mh,
            (chinX * mw).toFloat(), (chinY * mh).toFloat(), (faceWidth * mw).toFloat(),
        )
        val ms = SystemClock.uptimeMillis() - t0
        segFrames++
        segMsSum += ms
        if (measure != null && confirm(measure, mw, mh, chinX, chinY, faceWidth)) {
            segOk++
            neck = measure.toMap(mw, mh) + mapOf(
                "refChinX" to chinX,
                "refChinY" to chinY,
                "refFaceWidth" to faceWidth,
            )
            neckAt = SystemClock.uptimeMillis()
        }
        saveDebugIfRequested(small, mask, mw, mh, measure, chinX, chinY)
    }

    /**
     * Filtra saltos sueltos de la segmentación. De frente, de vez en cuando un
     * lado de la base se iba al hombro y el centro saltaba un cuarto de cara
     * (visto en dispositivo, 2026-11-05). Una medida que se aparta de la
     * anterior solo se acepta si la siguiente la confirma; si la persona se
     * movió de verdad, la confirmación llega en la medida siguiente.
     */
    private fun confirm(
        m: NeckMeasure.Result, mw: Int, mh: Int,
        chinX: Double, chinY: Double, faceWidth: Double,
    ): Boolean {
        if (faceWidth <= 0) return false
        val aspect = mh.toDouble() / mw
        val rel = doubleArrayOf(
            ((m.leftX + m.rightX) / 2.0 / mw - chinX) / faceWidth,
            ((m.leftY + m.rightY) / 2.0 / mh - chinY) * aspect / faceWidth,
            (m.rightX - m.leftX).toDouble() / mw / faceWidth,
        )
        fun near(a: DoubleArray, b: DoubleArray) =
            kotlin.math.abs(a[0] - b[0]) < 0.15 &&
                kotlin.math.abs(a[1] - b[1]) < 0.15 &&
                kotlin.math.abs(a[2] - b[2]) < 0.2 * b[2]

        val prev = accepted
        val fresh = SystemClock.uptimeMillis() - neckAt < NECK_MAX_AGE_MS
        if (prev == null || !fresh || near(rel, prev)) {
            accepted = rel
            candidate = null
            return true
        }
        val cand = candidate
        if (cand != null && near(rel, cand)) {
            accepted = rel
            candidate = null
            return true
        }
        candidate = rel
        return false
    }

    private fun countFace(convMs: Long, ms: Long) {
        val now = SystemClock.uptimeMillis()
        if (statsStart == 0L) statsStart = now
        faceFrames++
        faceMsSum += ms
        convMsSum += convMs
        val elapsed = now - statsStart
        if (elapsed >= 5000) {
            val seg = segFrames
            Log.i(
                TAG,
                "cara ${"%.1f".format(faceFrames * 1000f / elapsed)} Hz " +
                    "(${convMsSum / max(1, faceFrames)} ms conversion + ${faceMsSum / max(1, faceFrames)} ms modelo), " +
                    "cuello ${"%.1f".format(seg * 1000f / elapsed)} Hz en ${if (gpuReady) "GPU" else "CPU"} " +
                    "(${segMsSum / max(1, seg)} ms, $segOk validas)",
            )
            statsStart = now
            faceFrames = 0
            faceMsSum = 0
            convMsSum = 0
            segFrames = 0
            segMsSum = 0
            segOk = 0
        }
    }

    // Búferes de la conversión, reutilizados entre frames (solo en [faceExec]).
    private var pixels: IntArray? = null
    private var upright: Bitmap? = null

    /**
     * NV21 a ARGB, rotado a vertical en la misma pasada. Coeficientes BT.601 de
     * rango limitado en aritmética entera (×1024).
     *
     * Se recorre por bloques de 2×2, que comparten su par de croma, y por
     * teselas de [TILE]: con la rotación de la cámara frontal (270°) cada fila
     * de la imagen se escribe como una columna, y escribir fila tras fila
     * saltaba de línea de caché en cada píxel. El destino es lineal en (x, y)
     * para cualquier rotación, `base + x·dx + y·dy`. El píxel y el mapa de bits
     * se reutilizan: antes se creaban dos búferes de ~1,4 MB por frame.
     * Medido en el Galaxy A15 (2026-11-08): de 26–30 ms por frame, la mitad
     * del tiempo de cada detección sin cara a la vista, a 10–13 ms.
     *
     * Las dimensiones de la cámara son pares; con una impar, la última fila o
     * columna quedaría sin convertir.
     */
    private fun toUprightBitmap(nv: ByteArray, w: Int, h: Int, stride: Int, rotation: Int): Bitmap {
        val r = ((rotation % 360) + 360) % 360
        val swapped = r == 90 || r == 270
        val ow = if (swapped) h else w
        val oh = if (swapped) w else h
        val base: Int
        val dx: Int
        val dy: Int
        when (r) {
            90 -> { base = ow - 1; dx = ow; dy = -1 }
            180 -> { base = (oh - 1) * ow + ow - 1; dx = -1; dy = -ow }
            270 -> { base = (w - 1) * ow; dx = -ow; dy = 1 }
            else -> { base = 0; dx = 1; dy = ow }
        }
        val px = pixels?.takeIf { it.size == ow * oh } ?: IntArray(ow * oh).also { pixels = it }
        val uvStart = stride * h
        val ew = w and 1.inv()
        val eh = h and 1.inv()
        var ty = 0
        while (ty < eh) {
            val yEnd = minOf(ty + TILE, eh)
            var tx = 0
            while (tx < ew) {
                val xEnd = minOf(tx + TILE, ew)
                var y = ty
                while (y < yEnd) {
                    val row0 = y * stride
                    val row1 = row0 + stride
                    val uvRow = uvStart + (y shr 1) * stride
                    var x = tx
                    while (x < xEnd) {
                        val v = (nv[uvRow + x].toInt() and 0xFF) - 128
                        val u = (nv[uvRow + x + 1].toInt() and 0xFF) - 128
                        val rv = 1634 * v
                        val guv = -833 * v - 400 * u
                        val bu = 2066 * u
                        val d = base + x * dx + y * dy
                        px[d] = argb(nv[row0 + x], rv, guv, bu)
                        px[d + dx] = argb(nv[row0 + x + 1], rv, guv, bu)
                        px[d + dy] = argb(nv[row1 + x], rv, guv, bu)
                        px[d + dx + dy] = argb(nv[row1 + x + 1], rv, guv, bu)
                        x += 2
                    }
                    y += 2
                }
                tx = xEnd
            }
            ty = yEnd
        }
        val bmp = upright?.takeIf { it.width == ow && it.height == oh && !it.isRecycled }
            ?: Bitmap.createBitmap(ow, oh, Bitmap.Config.ARGB_8888).also { upright = it }
        bmp.setPixels(px, 0, ow, 0, 0, ow, oh)
        return bmp
    }

    @Suppress("NOTHING_TO_INLINE")
    private inline fun argb(luma: Byte, rv: Int, guv: Int, bu: Int): Int {
        val yy = max(0, (luma.toInt() and 0xFF) - 16) * 1192
        var rr = (yy + rv) shr 10
        if (rr < 0) rr = 0 else if (rr > 255) rr = 255
        var gg = (yy + guv) shr 10
        if (gg < 0) gg = 0 else if (gg > 255) gg = 255
        var bb = (yy + bu) shr 10
        if (bb < 0) bb = 0 else if (bb > 255) bb = 255
        return -0x1000000 or (rr shl 16) or (gg shl 8) or bb
    }

    /**
     * Con el archivo `neck_debug.flag` en la carpeta de la app, guarda cada 2 s
     * el frame con la máscara y los puntos medidos. Es para revisar en
     * dispositivo qué se está midiendo; sin el archivo no hace nada.
     */
    private fun saveDebugIfRequested(
        small: Bitmap, mask: ByteArray, mw: Int, mh: Int,
        measure: NeckMeasure.Result?, chinX: Double, chinY: Double,
    ) {
        val dir = context.getExternalFilesDir(null) ?: return
        if (!File(dir, "neck_debug.flag").exists()) return
        val now = SystemClock.uptimeMillis()
        if (now - lastDebugSave < 2000) return
        lastDebugSave = now

        val out = small.copy(Bitmap.Config.ARGB_8888, true)
        val colors = mapOf(
            NeckMeasure.BODY_SKIN to Color.argb(110, 255, 0, 0),
            NeckMeasure.FACE_SKIN to Color.argb(90, 0, 255, 0),
            NeckMeasure.CLOTHES to Color.argb(90, 0, 0, 255),
        )
        for (y in 0 until mh) for (x in 0 until mw) {
            val c = colors[mask[y * mw + x].toInt() and 0xFF] ?: continue
            out.setPixel(x, y, blend(out.getPixel(x, y), c))
        }
        val canvas = Canvas(out)
        val dot = Paint().apply { style = Paint.Style.FILL }
        fun mark(x: Float, y: Float, color: Int) {
            dot.color = color
            canvas.drawCircle(x, y, 3f, dot)
        }
        mark((chinX * mw).toFloat(), (chinY * mh).toFloat(), Color.WHITE)
        if (measure != null) {
            mark(measure.leftX, measure.leftY, Color.YELLOW)
            mark(measure.rightX, measure.rightY, Color.YELLOW)
            if (measure.hasFront) mark(measure.frontX, measure.frontY, Color.CYAN)
        }
        val folder = File(dir, "neck_debug").apply { mkdirs() }
        FileOutputStream(File(folder, "neck_$now.png")).use {
            out.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }

    private fun blend(base: Int, over: Int): Int {
        val a = Color.alpha(over) / 255f
        fun ch(b: Int, o: Int) = (b * (1 - a) + o * a).toInt()
        return Color.rgb(
            ch(Color.red(base), Color.red(over)),
            ch(Color.green(base), Color.green(over)),
            ch(Color.blue(base), Color.blue(over)),
        )
    }
}

/**
 * Forma del cuello sobre la máscara de segmentación.
 *
 * Se baja desde el mentón fila por fila siguiendo la franja de piel del cuerpo
 * que lo contiene. De cada lado interesa **dónde el borde del cuello toca la
 * ropa**: por ahí sale la cadena de detrás del cuello. Sin ropa a ese lado
 * (hombros descubiertos) se toma donde el borde se abre hacia el hombro. La
 * franja acaba en el escote; su último punto es el centro delantero del torso,
 * del que sale el giro del cuerpo.
 */
object NeckMeasure {
    /**
     * Valores de la máscara. **Medidos en dispositivo** (2026-11-04): el modelo
     * declara `background, hair, body-skin, face-skin, clothes, others`, pero
     * la máscara trae la clase menos uno, con el fondo en 255. El cuello salía
     * con 1, la cara con 2, la ropa con 3 y las gafas con 4.
     */
    const val BODY_SKIN = 1
    const val FACE_SKIN = 2
    const val CLOTHES = 3

    class Result(
        val leftX: Float, val leftY: Float,
        val rightX: Float, val rightY: Float,
        val hasFront: Boolean, val frontX: Float, val frontY: Float,
        /** Ancho de la columna del cuello sobre la ropa, en píxeles; 0 si no se vio. */
        val narrow: Float,
        /**
         * Centro de la columna del cuello, o negativo si no se vio. Es el eje
         * del cuello: la base, de lado, incluye el trapecio de la nuca y su
         * punto medio queda corrido hacia atrás.
         */
        val columnX: Float,
    ) {
        fun toMap(w: Int, h: Int): Map<String, Any> = mapOf(
            "leftX" to (leftX / w).toDouble(), "leftY" to (leftY / h).toDouble(),
            "rightX" to (rightX / w).toDouble(), "rightY" to (rightY / h).toDouble(),
            "hasFront" to hasFront,
            "frontX" to (frontX / w).toDouble(), "frontY" to (frontY / h).toDouble(),
            "narrow" to (narrow / w).toDouble(),
            "columnX" to (if (columnX < 0) -1.0 else (columnX / w).toDouble()),
        )
    }

    fun measure(m: ByteArray, w: Int, h: Int, chinX: Float, chinY: Float, faceWidth: Float): Result? {
        if (faceWidth <= 2f) return null
        fun at(x: Int, y: Int) = m[y * w + x].toInt() and 0xFF

        val reach = (0.35f * faceWidth).toInt().coerceAtLeast(2)
        val minRun = 0.2f * faceWidth
        val yStart = (chinY - 0.05f * faceWidth).toInt().coerceIn(0, h - 1)
        val yEnd = (chinY + 1.6f * faceWidth).toInt().coerceIn(0, h - 1)

        val ys = ArrayList<Int>()
        val ls = ArrayList<Int>()
        val rs = ArrayList<Int>()
        val leftKind = ArrayList<Int>()
        val rightKind = ArrayList<Int>()
        var seed = chinX.toInt().coerceIn(0, w - 1)
        var started = false
        var endedOnClothes = false

        for (y in yStart..yEnd) {
            var x0 = -1
            for (d in 0..reach) {
                if (seed - d >= 0 && at(seed - d, y) == BODY_SKIN) { x0 = seed - d; break }
                if (seed + d < w && at(seed + d, y) == BODY_SKIN) { x0 = seed + d; break }
            }
            if (x0 < 0) {
                if (!started) continue
                endedOnClothes = at(seed, y) == CLOTHES
                break
            }
            var l = x0
            while (l > 0 && at(l - 1, y) == BODY_SKIN) l--
            var r = x0
            while (r < w - 1 && at(r + 1, y) == BODY_SKIN) r++
            // No se arranca con un hilo de piel junto a la mandíbula: la
            // semilla se iría hacia ese lado.
            if (!started && r - l + 1 < minRun) continue
            started = true
            ys.add(y)
            ls.add(l)
            rs.add(r)
            leftKind.add(if (l > 0) at(l - 1, y) else -1)
            rightKind.add(if (r < w - 1) at(r + 1, y) else -1)
            seed = (l + r) / 2
        }
        if (ys.size < 3) return null

        val flare = 0.12f * faceWidth
        fun sideBase(kinds: List<Int>, edges: List<Int>, outward: Int): Int {
            for (i in kinds.indices) if (kinds[i] == CLOTHES) return i
            val ref = edges.take(3).sorted()[minOf(1, edges.size - 1)]
            for (i in edges.indices) if ((edges[i] - ref) * outward > flare) return i
            return edges.size - 1
        }
        val il = sideBase(leftKind, ls, -1)
        val ir = sideBase(rightKind, rs, 1)

        val upper = minOf(il, ir)
        val cleanRows = (0 until upper).filter { leftKind[it] != CLOTHES && rightKind[it] != CLOTHES }
        val clean = cleanRows.map { rs[it] - ls[it] + 1 }.sorted()
        val narrow = if (clean.size >= 2) clean[clean.size / 2].toFloat() else 0f
        val centers = cleanRows.map { (ls[it] + rs[it] + 1) / 2f }.sorted()
        val columnX = if (centers.size >= 2) centers[centers.size / 2] else -1f

        val baseWidth = rs[ir] - ls[il] + 1
        if (baseWidth < 0.35f * faceWidth || baseWidth > 1.4f * faceWidth) return null

        val last = ys.size - 1
        return Result(
            leftX = ls[il].toFloat(), leftY = ys[il].toFloat(),
            rightX = rs[ir] + 1f, rightY = ys[ir].toFloat(),
            hasFront = endedOnClothes,
            frontX = (ls[last] + rs[last] + 1) / 2f, frontY = ys[last].toFloat(),
            narrow = narrow,
            columnX = columnX,
        )
    }
}
