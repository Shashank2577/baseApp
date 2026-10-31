package dev.baseplatform.base_models

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Android side of the shared model store.
 *
 * Android gives every app its own private storage, so apps cannot open one
 * folder in place the way iOS App Groups or a desktop folder can. Instead each
 * app keeps its models in `filesDir/shared-models`, and before downloading a
 * model it asks its sibling apps (same signing key, found through
 * [BaseModelsProvider]) for a copy. The model crosses the network once per
 * device; each app that uses it keeps its own copy on disk.
 */
class BaseModelsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val io = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "base/models")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        io.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "storeDir" -> result.success(storeDir(context).path)
            "siblings" -> result.success(siblings(call.argument<String>("action")!!))
            "copyFromSibling" -> io.execute {
                try {
                    val bytes = copyFromSibling(
                        call.argument<String>("authority")!!,
                        call.argument<String>("modelId")!!,
                        call.argument<String>("file")!!,
                        call.argument<String>("dest")!!,
                    )
                    post { result.success(bytes) }
                } catch (e: Exception) {
                    post { result.error("sibling", e.message ?: e.javaClass.simpleName, null) }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun post(block: () -> Unit) = android.os.Handler(android.os.Looper.getMainLooper()).post(block)

    /** Providers of other installed apps that answer the platform's discovery action. */
    private fun siblings(action: String): List<String> {
        val pm = context.packageManager
        val found = if (android.os.Build.VERSION.SDK_INT >= 33) {
            pm.queryIntentContentProviders(Intent(action), PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentContentProviders(Intent(action), 0)
        }
        return found.mapNotNull { it.providerInfo }
            .filter { it.packageName != context.packageName }
            .map { it.authority }
    }

    private fun copyFromSibling(authority: String, modelId: String, file: String, dest: String): Long {
        require(BaseModelsProvider.isPlainName(modelId) && BaseModelsProvider.isPlainName(file)) { "bad name" }
        val out = File(dest)
        require(out.canonicalPath.startsWith(storeDir(context).canonicalPath)) { "destination outside the store" }
        val uri = Uri.parse("content://$authority/$modelId/$file")
        val input = context.contentResolver.openInputStream(uri) ?: error("$authority has no $modelId/$file")
        input.use { src -> out.outputStream().use { dst -> return src.copyTo(dst, 1 shl 20) } }
    }

    companion object {
        fun storeDir(context: Context): File = File(context.filesDir, "shared-models").apply { mkdirs() }
    }
}
