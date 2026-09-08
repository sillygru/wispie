package com.sillygru.wispie

import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    private val channelName = "wispie/storage"
    private val appChannelName = "wispie/app"
    private val openFileChannelName = "wispie/open-file"
    private var openFileChannel: MethodChannel? = null
    private val requestPickTree = 9001
    private var pendingResult: MethodChannel.Result? = null
    /**
     * Files staged from ACTION_VIEW / ACTION_SEND intents, waiting for Flutter
     * to pull (cold start) or push-acknowledge (warm start) them. Only ever
     * touched on the main thread, except from [ioExecutor] via [mainHandler].
     */
    private val pendingOpenFiles = mutableListOf<Map<String, Any?>>()
    private lateinit var volumeMonitorPlugin: VolumeMonitorPlugin
    private lateinit var powerStatePlugin: PowerStatePlugin
    private lateinit var displayRefreshPlugin: DisplayRefreshPlugin

    /**
     * Handlers that stream whole audio files run here instead of on the platform
     * main thread, where copying a 40 MB track froze the UI for seconds every
     * time metadata was saved.
     *
     * Single-threaded on purpose: SAF operations against one document tree are
     * serialized rather than racing each other.
     */
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Runs [block] on [ioExecutor], giving it a result that always reports back
     * on the main thread — a MethodChannel.Result must be completed there.
     */
    private fun onIoThread(result: MethodChannel.Result, block: (MethodChannel.Result) -> Unit) {
        val proxy = MainThreadResult(result, mainHandler)
        ioExecutor.execute {
            try {
                block(proxy)
            } catch (e: Exception) {
                proxy.error("unexpected", e.message, null)
            }
        }
    }

    /** Forwards a [MethodChannel.Result] onto the main thread. */
    private class MainThreadResult(
        private val delegate: MethodChannel.Result,
        private val handler: Handler
    ) : MethodChannel.Result {
        override fun success(value: Any?) {
            handler.post { delegate.success(value) }
        }

        override fun error(code: String, message: String?, details: Any?) {
            handler.post { delegate.error(code, message, details) }
        }

        override fun notImplemented() {
            handler.post { delegate.notImplemented() }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Watchdog for EMUI swipe-to-kill cleanup; best-effort so a denied
        // background start never blocks cold start.
        try {
            startService(Intent(this, WispieTaskCleanupService::class.java))
        } catch (_: SecurityException) {
        } catch (_: Exception) {
        }
        // Cold start via Open-with / Share: the read grant is only valid while
        // this intent is alive, so staging starts now; delivery to Flutter
        // happens when the engine (and channel) is ready.
        handleOpenIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // singleTop: taps while running arrive here instead of a new activity.
        setIntent(intent)
        handleOpenIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            openFileChannelName
        )
        openFileChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Cold-start pull: returns staged files and clears the queue.
                "getInitialOpenFiles" -> {
                    val files = pendingOpenFiles.toList()
                    pendingOpenFiles.clear()
                    result.success(files)
                }
                else -> result.notImplemented()
            }
        }

        // Initialize volume monitor plugin
        volumeMonitorPlugin = VolumeMonitorPlugin()
        volumeMonitorPlugin.initialize(flutterEngine, this)

        // Battery saver state, used to thin out the player's animation
        powerStatePlugin = PowerStatePlugin()
        powerStatePlugin.initialize(flutterEngine, this)

        displayRefreshPlugin = DisplayRefreshPlugin()
        displayRefreshPlugin.initialize(flutterEngine, this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSdkInt" -> result.success(android.os.Build.VERSION.SDK_INT)
                    // pickTree must stay on the main thread: it starts an
                    // activity and is completed from onActivityResult.
                    "pickTree" -> handlePickTree(result)
                    "createFolder" -> handleCreateFolder(call.arguments as Map<*, *>, result)
                    "renameFile" -> handleRenameFile(call.arguments as Map<*, *>, result)
                    "deleteFile" -> handleDeleteFile(call.arguments as Map<*, *>, result)
                    // The rest copy file contents, so they go to the IO thread.
                    "moveFile" -> onIoThread(result) { handleMoveFile(call.arguments as Map<*, *>, it) }
                    "moveFolder" -> onIoThread(result) { handleMoveFolder(call.arguments as Map<*, *>, it) }
                    "writeFileFromPath" ->
                        onIoThread(result) { handleWriteFileFromPath(call.arguments as Map<*, *>, it) }
                    "readFile" -> onIoThread(result) { handleReadFile(call.arguments as Map<*, *>, it) }
                    // MediaStore fallback for devices where direct file listing
                    // finds entries but reads are denied (SD cards, odd mounts).
                    "queryAudioMedia" -> onIoThread(result) { handleQueryAudioMedia(it) }
                    else -> result.notImplemented()
                }
            }

        // App control channel (restart, etc.)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "restartApp" -> handleRestartApp(result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Collects audio URIs from Open-with (VIEW) and Share (SEND / SEND_MULTIPLE)
     * intents. Remote http(s) links are forwarded as-is for streaming; local
     * content is copied into the app cache on [ioExecutor] because the
     * transient read grant may not survive past this intent.
     */
    private fun handleOpenIntent(intent: Intent?) {
        if (intent == null) return
        val uris: List<Uri> = when (intent.action) {
            Intent.ACTION_VIEW -> {
                val data = intent.data ?: return
                listOf(data)
            }
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val shared: Uri? = intent.getParcelableExtra(Intent.EXTRA_STREAM)
                if (shared == null) return
                listOf(shared)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                val shared: ArrayList<Uri>? =
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                if (shared.isNullOrEmpty()) return
                shared.toList()
            }
            else -> return
        }
        if (uris.isEmpty()) return
        ioExecutor.execute {
            val staged = uris.mapNotNull { stageOneOpenUri(it) }
            if (staged.isEmpty()) return@execute
            mainHandler.post {
                pendingOpenFiles.addAll(staged)
                pushStagedOpenFiles(staged)
            }
        }
    }

    /**
     * Warm-start push: if Flutter is already listening, deliver just-staged
     * files now and drop them from the pending queue on success. If the channel
     * is absent (cold start still initializing) or delivery fails, the files
     * stay pending for the [getInitialOpenFiles] pull.
     */
    private fun pushStagedOpenFiles(staged: List<Map<String, Any?>>) {
        val channel = openFileChannel ?: return
        channel.invokeMethod(
            "onOpenFiles",
            staged,
            object : MethodChannel.Result {
                override fun success(value: Any?) {
                    pendingOpenFiles.removeAll(staged.toSet())
                }

                override fun error(code: String, message: String?, details: Any?) {
                    // Kept pending for the pull; a later push retries delivery.
                }

                override fun notImplemented() {
                    // Kept pending for the pull.
                }
            }
        )
    }

    private fun stageOneOpenUri(uri: Uri): Map<String, Any?>? {
        // Streamed links are never downloaded up front; the player streams them.
        if (uri.scheme == "http" || uri.scheme == "https") {
            val name = uri.lastPathSegment?.substringAfterLast('/') ?: "stream"
            if (!isSupportedOpenFileName(name)) return null
            return mapOf(
                "remoteUrl" to uri.toString(),
                "displayName" to name,
                "mimeType" to null
            )
        }
        val rawName = resolveOpenFileName(uri) ?: return null
        if (!isSupportedOpenFileName(rawName)) return null
        val mimeType = try {
            if (uri.scheme == "content") contentResolver.getType(uri) else null
        } catch (_: SecurityException) {
            return null
        } catch (_: Exception) {
            null
        }
        val stagedPath = copyOpenUriToCache(uri, rawName) ?: return null
        // Byte size lets Dart match the opened file against identical library
        // entries (same name, same size) instead of playing a duplicate.
        val sizeBytes = resolveOpenFileSize(uri, stagedPath)
        return mapOf(
            "path" to stagedPath,
            "displayName" to rawName,
            "mimeType" to mimeType,
            "sizeBytes" to sizeBytes
        )
    }

    /** Best-effort byte size of [uri]; falls back to the staged copy. Null when unknown. */
    private fun resolveOpenFileSize(uri: Uri, stagedPath: String): Long? {
        if (uri.scheme == "content") {
            var cursor: Cursor? = null
            try {
                cursor = contentResolver.query(
                    uri,
                    arrayOf(OpenableColumns.SIZE),
                    null,
                    null,
                    null
                )
                if (cursor != null && cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (index >= 0) {
                        val size = cursor.getLong(index)
                        if (size > 0) return size
                    }
                }
            } catch (_: SecurityException) {
                return null
            } catch (_: Exception) {
            } finally {
                try {
                    cursor?.close()
                } catch (_: Exception) {
                }
            }
        } else if (uri.scheme == "file") {
            try {
                val length = java.io.File(uri.path ?: return null).length()
                if (length > 0) return length
            } catch (_: SecurityException) {
                return null
            } catch (_: Exception) {
            }
        }
        return try {
            val length = java.io.File(stagedPath).length()
            if (length > 0) length else null
        } catch (_: SecurityException) {
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveOpenFileName(uri: Uri): String? {
        if (uri.scheme == "file") {
            return uri.path?.substringAfterLast('/')?.takeIf { it.isNotEmpty() }
        }
        if (uri.scheme != "content") return null
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            } else {
                uri.lastPathSegment?.substringAfterLast('/')
            }
        } catch (_: SecurityException) {
            null
        } catch (_: Exception) {
            null
        } finally {
            try {
                cursor?.close()
            } catch (_: Exception) {
            }
        }
    }

    /** Copies [uri] into cacheDir/open-with so playback outlives the grant. */
    private fun copyOpenUriToCache(uri: Uri, displayName: String): String? {
        return try {
            val dir = java.io.File(cacheDir, "open-with")
            if (!dir.exists() && !dir.mkdirs()) return null
            val target = uniqueOpenFile(dir, sanitizeOpenFileName(displayName))
            if (uri.scheme == "file") {
                val sourcePath = uri.path ?: return null
                java.io.File(sourcePath).inputStream().use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
            } else {
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                } ?: return null
            }
            target.absolutePath
        } catch (_: SecurityException) {
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun uniqueOpenFile(dir: java.io.File, name: String): java.io.File {
        var candidate = java.io.File(dir, name)
        if (!candidate.exists()) return candidate
        val base = name.substringBeforeLast('.', name)
        val ext = name.substringAfterLast('.', "")
        var counter = 1
        while (candidate.exists()) {
            val suffixed = if (ext.isEmpty()) "$base-$counter" else "$base-$counter.$ext"
            candidate = java.io.File(dir, suffixed)
            counter++
        }
        return candidate
    }

    private fun sanitizeOpenFileName(name: String): String {
        val clean = name.replace(Regex("[^A-Za-z0-9._\\- ]"), "_").trim()
        if (clean.isEmpty() || clean == "." || clean == "..") {
            return "shared_audio"
        }
        return clean.takeLast(120)
    }

    private fun isSupportedOpenFileName(name: String): Boolean {
        val ext = name.substringAfterLast('.', "").lowercase()
        return ext in openFileAudioExtensions
    }

    private fun handleRestartApp(result: MethodChannel.Result) {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                finishAffinity()
                Runtime.getRuntime().exit(0)
                result.success(true)
            } else {
                result.error("no_intent", "Could not get launch intent", null)
            }
        } catch (e: Exception) {
            result.error("restart_failed", e.message, null)
        }
    }

    private fun handlePickTree(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("in_progress", "Another picker is active", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        intent.addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
        startActivityForResult(intent, requestPickTree)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == requestPickTree) {
            val result = pendingResult
            pendingResult = null

            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                val flags = data.flags and
                    (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                contentResolver.takePersistableUriPermission(uri, flags)
                val path = treeUriToPath(uri)
                result?.success(mapOf("treeUri" to uri.toString(), "path" to path))
            } else {
                result?.success(null)
            }
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun handleCreateFolder(args: Map<*, *>, result: MethodChannel.Result) {
        val treeUri = args["treeUri"] as? String
        val relativePath = args["relativePath"] as? String
        if (treeUri.isNullOrBlank() || relativePath.isNullOrBlank()) {
            result.error("invalid_args", "treeUri and relativePath required", null)
            return
        }

        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
        if (root == null) {
            result.error("invalid_tree", "Unable to access tree URI", null)
            return
        }

        val created = findOrCreateDirectory(root, relativePath)
        if (created == null) {
            result.error("create_failed", "Unable to create folder", null)
        } else {
            result.success(true)
        }
    }

    private fun handleMoveFile(args: Map<*, *>, result: MethodChannel.Result) {
        val treeUri = args["treeUri"] as? String
        val sourceRelativePath = args["sourceRelativePath"] as? String
        val targetRelativeDir = args["targetRelativeDir"] as? String
        val targetFileName = args["targetFileName"] as? String

        if (treeUri.isNullOrBlank() || sourceRelativePath.isNullOrBlank() || targetRelativeDir == null) {
            result.error("invalid_args", "treeUri/sourceRelativePath/targetRelativeDir required", null)
            return
        }

        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
        if (root == null) {
            result.error("invalid_tree", "Unable to access tree URI", null)
            return
        }

        val source = findDocument(root, sourceRelativePath)
        if (source == null || !source.isFile) {
            result.error("not_found", "Source file not found", null)
            return
        }

        val targetDir = if (targetRelativeDir.isBlank()) root else findOrCreateDirectory(root, targetRelativeDir)
        if (targetDir == null) {
            result.error("target_missing", "Target directory not found", null)
            return
        }

        val fileName = targetFileName ?: (source.name ?: "file")
        val type = source.type ?: "application/octet-stream"
        val dest = targetDir.createFile(type, fileName)
        if (dest == null) {
            result.error("create_failed", "Unable to create destination file", null)
            return
        }

        val copied = copyDocument(source, dest)
        if (!copied) {
            result.error("copy_failed", "Failed to copy file", null)
            return
        }

        source.delete()
        result.success(true)
    }

    private fun handleMoveFolder(args: Map<*, *>, result: MethodChannel.Result) {
        val treeUri = args["treeUri"] as? String
        val sourceRelativePath = args["sourceRelativePath"] as? String
        val targetParentRelativePath = args["targetParentRelativePath"] as? String

        if (treeUri.isNullOrBlank() || sourceRelativePath.isNullOrBlank() || targetParentRelativePath.isNullOrBlank()) {
            result.error("invalid_args", "treeUri/sourceRelativePath/targetParentRelativePath required", null)
            return
        }

        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
        if (root == null) {
            result.error("invalid_tree", "Unable to access tree URI", null)
            return
        }

        val source = findDocument(root, sourceRelativePath)
        if (source == null || !source.isDirectory) {
            result.error("not_found", "Source folder not found", null)
            return
        }

        val targetParent = findOrCreateDirectory(root, targetParentRelativePath)
        if (targetParent == null) {
            result.error("target_missing", "Target parent not found", null)
            return
        }

        val folderName = source.name ?: "folder"
        val destFolder = targetParent.createDirectory(folderName)
        if (destFolder == null) {
            result.error("create_failed", "Unable to create destination folder", null)
            return
        }

        val copied = copyDirectory(source, destFolder)
        if (!copied) {
            result.error("copy_failed", "Failed to copy folder", null)
            return
        }

        source.delete()
        result.success(true)
    }

    private fun handleRenameFile(args: Map<*, *>, result: MethodChannel.Result) {
        val treeUri = args["treeUri"] as? String
        val sourceRelativePath = args["sourceRelativePath"] as? String
        val newName = args["newName"] as? String

        if (treeUri.isNullOrBlank() || sourceRelativePath.isNullOrBlank() || newName.isNullOrBlank()) {
            result.error("invalid_args", "treeUri/sourceRelativePath/newName required", null)
            return
        }

        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
        if (root == null) {
            result.error("invalid_tree", "Unable to access tree URI", null)
            return
        }

        val source = findDocument(root, sourceRelativePath)
        if (source == null || !source.isFile) {
            result.error("not_found", "Source file not found", null)
            return
        }

        val renamed = source.renameTo(newName)
        if (!renamed) {
            result.error("rename_failed", "Failed to rename file", null)
        } else {
            result.success(true)
        }
    }

    private fun handleDeleteFile(args: Map<*, *>, result: MethodChannel.Result) {
        val treeUri = args["treeUri"] as? String
        val sourceRelativePath = args["sourceRelativePath"] as? String

        if (treeUri.isNullOrBlank() || sourceRelativePath.isNullOrBlank()) {
            result.error("invalid_args", "treeUri/sourceRelativePath required", null)
            return
        }

        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
        if (root == null) {
            result.error("invalid_tree", "Unable to access tree URI", null)
            return
        }

        val source = findDocument(root, sourceRelativePath)
        if (source == null || !source.isFile) {
            result.error("not_found", "Source file not found", null)
            return
        }

        val deleted = source.delete()
        if (!deleted) {
            result.error("delete_failed", "Failed to delete file", null)
        } else {
            result.success(true)
        }
    }

    private fun handleWriteFileFromPath(args: Map<*, *>, result: MethodChannel.Result) {
        val treeUri = args["treeUri"] as? String
        val sourceRelativePath = args["sourceRelativePath"] as? String
        val sourcePath = args["sourcePath"] as? String

        if (treeUri.isNullOrBlank() || sourceRelativePath.isNullOrBlank() || sourcePath.isNullOrBlank()) {
            result.error("invalid_args", "treeUri/sourceRelativePath/sourcePath required", null)
            return
        }

        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
        if (root == null) {
            result.error("invalid_tree", "Unable to access tree URI", null)
            return
        }

        val cleanPath = sourceRelativePath.trim('/')
        val fileName = cleanPath.substringAfterLast('/')
        val parentPath = cleanPath.substringBeforeLast('/', "")
        val parent = findOrCreateDirectory(root, parentPath)
        if (parent == null) {
            result.error("target_missing", "Target directory not found", null)
            return
        }

        val existing = parent.findFile(fileName)
        val mimeType = guessMimeType(fileName)

        // Write to a temp file first to avoid corrupting the original on partial writes.
        val tempName = "$fileName.tmp"
        parent.findFile(tempName)?.delete()
        val tempTarget = parent.createFile(mimeType, tempName)
        if (tempTarget == null) {
            result.error("create_failed", "Unable to create temp file", null)
            return
        }

        try {
            File(sourcePath).inputStream().use { input ->
                contentResolver.openOutputStream(tempTarget.uri, "w")?.use { output ->
                    input.copyTo(output)
                } ?: run {
                    result.error("write_failed", "Unable to open output stream", null)
                    return
                }
            }
            if (existing != null && !existing.delete()) {
                result.error("delete_failed", "Failed to delete existing file", null)
                tempTarget.delete()
                return
            }
            val renamed = tempTarget.renameTo(fileName)
            if (!renamed) {
                result.error("rename_failed", "Failed to rename temp file", null)
                tempTarget.delete()
                return
            }
            result.success(true)
        } catch (e: Exception) {
            tempTarget.delete()
            result.error("write_failed", "Failed to write file", e.message)
        }
    }

    private fun handleReadFile(args: Map<*, *>, result: MethodChannel.Result) {
        val treeUri = args["treeUri"] as? String
        val relativePath = args["relativePath"] as? String

        if (treeUri.isNullOrBlank() || relativePath.isNullOrBlank()) {
            result.error("invalid_args", "treeUri and relativePath required", null)
            return
        }

        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
        if (root == null) {
            result.error("invalid_tree", "Unable to access tree URI", null)
            return
        }

        val document = findDocument(root, relativePath)
        if (document == null || !document.isFile) {
            result.error("not_found", "File not found", null)
            return
        }

        try {
            contentResolver.openInputStream(document.uri)?.use { input ->
                val content = input.bufferedReader().use { it.readText() }
                result.success(content)
            } ?: run {
                result.error("read_failed", "Unable to open input stream", null)
            }
        } catch (e: Exception) {
            result.error("read_failed", "Failed to read file: ${e.message}", null)
        }
    }

    private fun handleQueryAudioMedia(result: MethodChannel.Result) {
        try {
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            } else {
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            }
            val projection = arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.DATA,
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.SIZE
            )
            // Skip ringtones/alarms/notifications; only real music files.
            val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
            val out = mutableListOf<Map<String, Any?>>()
            contentResolver.query(collection, projection, selection, null, null)?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
                val nameCol = cursor.getColumnIndex(MediaStore.Audio.Media.DISPLAY_NAME)
                val sizeCol = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val contentUri = ContentUris.withAppendedId(collection, id).toString()
                    val filePath = if (dataCol >= 0) cursor.getString(dataCol) else null
                    val displayName = if (nameCol >= 0) cursor.getString(nameCol) else ""
                    val size = if (sizeCol >= 0) cursor.getLong(sizeCol) else 0L
                    out.add(
                        mapOf(
                            "filePath" to filePath,
                            "contentUri" to contentUri,
                            "displayName" to (displayName ?: ""),
                            "sizeBytes" to size
                        )
                    )
                }
            }
            result.success(out)
        } catch (e: SecurityException) {
            result.error("no_permission", "MediaStore query denied: ${e.message}", null)
        } catch (e: Exception) {
            result.error("query_failed", "MediaStore query failed: ${e.message}", null)
        }
    }

    private fun treeUriToPath(uri: Uri): String? {        val docId = DocumentsContract.getTreeDocumentId(uri)
        val parts = docId.split(":")
        if (parts.isEmpty()) return null

        val volume = parts[0]
        val rel = if (parts.size > 1) parts[1] else ""
        return if (volume == "primary") {
            val base = Environment.getExternalStorageDirectory().path
            if (rel.isEmpty()) base else "$base/$rel"
        } else {
            val storageRoot = File("/storage/$volume")
            if (!storageRoot.exists()) return null
            if (rel.isEmpty()) storageRoot.path else "${storageRoot.path}/$rel"
        }
    }

    private fun findDocument(root: DocumentFile, relativePath: String): DocumentFile? {
        val clean = relativePath.trim('/').takeIf { it.isNotEmpty() } ?: return root
        var current: DocumentFile? = root
        for (segment in clean.split('/')) {
            current = current?.findFile(segment)
            if (current == null) return null
        }
        return current
    }

    private fun findOrCreateDirectory(root: DocumentFile, relativePath: String): DocumentFile? {
        val clean = relativePath.trim('/').takeIf { it.isNotEmpty() } ?: return root
        var current: DocumentFile? = root
        for (segment in clean.split('/')) {
            var next = current?.findFile(segment)
            if (next == null) {
                next = current?.createDirectory(segment)
            }
            if (next == null) return null
            current = next
        }
        return current
    }

    private fun copyDocument(source: DocumentFile, dest: DocumentFile): Boolean {
        return try {
            contentResolver.openInputStream(source.uri)?.use { input ->
                contentResolver.openOutputStream(dest.uri, "w")?.use { output ->
                    input.copyTo(output)
                }
            } ?: return false
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun copyDirectory(source: DocumentFile, dest: DocumentFile): Boolean {
        for (child in source.listFiles()) {
            if (child.isDirectory) {
                val dirName = child.name ?: return false
                val newDir = dest.createDirectory(dirName) ?: return false
                if (!copyDirectory(child, newDir)) return false
            } else if (child.isFile) {
                val fileName = child.name ?: return false
                val type = child.type ?: "application/octet-stream"
                val newFile = dest.createFile(type, fileName) ?: return false
                if (!copyDocument(child, newFile)) return false
            }
        }
        return true
    }

    private fun guessMimeType(fileName: String): String {
        val extension = fileName.substringAfterLast('.', "").lowercase()
        val mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
        return mimeType ?: "application/octet-stream"
    }

    companion object {
        /** Audio-only, mirroring the scanner's supported list minus video. */
        private val openFileAudioExtensions = setOf(
            "mp3", "m4a", "wav", "flac", "ogg", "wma", "aac", "m4b", "opus"
        )
    }

    override fun onDestroy() {
        ioExecutor.shutdown()
        openFileChannel?.setMethodCallHandler(null)
        openFileChannel = null
        super.onDestroy()
        if (::volumeMonitorPlugin.isInitialized) {
            volumeMonitorPlugin.cleanup()
        }
        if (::powerStatePlugin.isInitialized) {
            powerStatePlugin.cleanup()
        }
        if (::displayRefreshPlugin.isInitialized) {
            displayRefreshPlugin.cleanup()
        }
    }
}
