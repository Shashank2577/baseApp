package dev.baseplatform.base_models

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException

/**
 * Hands this app's finished model files to sibling apps, read-only.
 *
 * Exported, but guarded by a signature-level permission (see the manifest), so
 * only apps signed with the same key can read it. Only files that the shared
 * registry lists as complete are served: never a `.part`, never anything
 * outside the store.
 *
 * URI: content://<applicationId>.basemodels/<modelId>/<file>
 */
class BaseModelsProvider : ContentProvider() {
    override fun onCreate() = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("read-only")
        val ctx = context ?: throw FileNotFoundException()
        val segments = uri.pathSegments
        if (segments.size != 2 || !segments.all(::isPlainName)) throw FileNotFoundException(uri.toString())
        val (modelId, name) = segments
        val root = BaseModelsPlugin.storeDir(ctx)
        val registry = File(root, "registry.json")
        if (!registry.exists()) throw FileNotFoundException(uri.toString())
        val recorded = JSONObject(registry.readText())
            .optJSONObject("models")?.optJSONObject(modelId)?.optJSONObject("files")?.optJSONObject(name)
            ?: throw FileNotFoundException(uri.toString())
        val file = File(File(root, modelId), name)
        if (!file.canonicalPath.startsWith(root.canonicalPath) || file.length() != recorded.optLong("bytes", -1)) {
            throw FileNotFoundException(uri.toString())
        }
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri) = "application/octet-stream"
    override fun query(uri: Uri, p: Array<out String>?, s: String?, a: Array<out String>?, o: String?): Cursor? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, s: String?, a: Array<out String>?) = 0
    override fun update(uri: Uri, v: ContentValues?, s: String?, a: Array<out String>?) = 0

    companion object {
        fun isPlainName(s: String) = s.isNotEmpty() && s != "." && s != ".." && !s.contains('/') && !s.contains('\\')
    }
}
