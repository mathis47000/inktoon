package com.example.inktoon

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.usb.UsbManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "inktoon/downloads"

    companion object {
        private const val NOTIF_CHANNEL_ID = "inktoon_export"
        private const val NOTIF_DOWNLOAD_ID = 1000
        private const val NOTIF_EXPORT_ID = 1001
        private const val NOTIF_TRANSFER_ID = 1002
        private const val NOTIF_DONE_ID = 1003
        private const val REQUEST_NOTIF_PERMISSION = 1
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingTransferResult: MethodChannel.Result? = null
    private var pendingFileUris: List<String> = emptyList()
    private var pendingFileNames: List<String> = emptyList()

    private val folderPickerLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { treeUri ->
        val result = pendingTransferResult ?: return@registerForActivityResult
        pendingTransferResult = null
        val uris = pendingFileUris
        val names = pendingFileNames
        pendingFileUris = emptyList()
        pendingFileNames = emptyList()

        if (treeUri == null) {
            result.error("CANCELLED", "Sélection annulée", null)
            return@registerForActivityResult
        }

        try {
            try {
                contentResolver.takePersistableUriPermission(
                    treeUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            } catch (_: Exception) { /* optional permission */ }
        } catch (e: Exception) {
            result.error("TRANSFER_ERROR", e.message, null)
            return@registerForActivityResult
        }

        val nm = NotificationManagerCompat.from(this)
        val total = uris.size
        showProgress(nm, NOTIF_TRANSFER_ID, "Transfert vers la liseuse", "0 / $total fichier(s)", 0, total)

        Thread {
            var transferred = 0
            try {
                for (i in uris.indices) {
                    showProgress(nm, NOTIF_TRANSFER_ID, "Transfert vers la liseuse", "${i + 1} / $total fichier(s)", i + 1, total)
                    try {
                        copyUriToTree(Uri.parse(uris[i]), treeUri, names[i])
                        transferred++
                    } catch (_: Exception) { /* continue */ }
                }
                val done = transferred
                mainHandler.post {
                    nm.cancel(NOTIF_TRANSFER_ID)
                    showDone(nm, NOTIF_DONE_ID, "Transfert terminé", "$done fichier(s) transféré(s) avec succès")
                    result.success(done)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    nm.cancel(NOTIF_TRANSFER_ID)
                    result.error("TRANSFER_ERROR", e.message, null)
                }
            }
        }.start()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_NOTIF_PERMISSION
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads"            -> handleSaveToDownloads(call, result)
                    "listExportedFiles"          -> handleListExportedFiles(result)
                    "transferToEReader"          -> handleTransferToEReader(call, result)
                    "getConnectedUsbDevices"     -> handleGetUsbDevices(result)
                    "updateDownloadNotification" -> handleUpdateDownloadNotif(call, result)
                    "cancelDownloadNotification" -> handleCancelDownloadNotif(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIF_CHANNEL_ID,
                "Exports et transferts",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Progression des exports et transferts de fichiers"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun canNotify(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return ContextCompat.checkSelfPermission(
                this, android.Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        }
        return true
    }

    private fun showProgress(nm: NotificationManagerCompat, id: Int, title: String, text: String, progress: Int, max: Int) {
        if (!canNotify()) return
        val notif = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(text)
            .setProgress(max, progress, max == 0)
            .setOngoing(true)
            .setSilent(true)
            .build()
        nm.notify(id, notif)
    }

    private fun showDone(nm: NotificationManagerCompat, id: Int, title: String, text: String) {
        if (!canNotify()) return
        val notif = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .build()
        nm.notify(id, notif)
    }

    // ── saveToDownloads ────────────────────────────────────────────────────────

    private fun handleSaveToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        val fileName = call.argument<String>("fileName")
        val subFolder = call.argument<String>("subFolder") ?: "Inktoon"
        if (filePath == null || fileName == null) {
            result.error("MISSING_ARG", "filePath and fileName are required", null); return
        }
        val nm = NotificationManagerCompat.from(this)
        showProgress(nm, NOTIF_EXPORT_ID, "Export en cours", fileName, 0, 0)

        Thread {
            try {
                val savedPath = saveToDownloads(filePath, fileName, subFolder)
                mainHandler.post {
                    nm.cancel(NOTIF_EXPORT_ID)
                    showDone(nm, NOTIF_DONE_ID, "Export terminé", fileName)
                    result.success(savedPath)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    nm.cancel(NOTIF_EXPORT_ID)
                    result.error("SAVE_ERROR", e.message, null)
                }
            }
        }.start()
    }

    private fun saveToDownloads(filePath: String, fileName: String, subFolder: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/$subFolder"
            val selection = "${MediaStore.Downloads.DISPLAY_NAME} = ? AND ${MediaStore.Downloads.RELATIVE_PATH} = ?"
            contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Downloads._ID),
                selection, arrayOf(fileName, "$relativePath/"), null
            )?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getLong(c.getColumnIndexOrThrow(MediaStore.Downloads._ID))
                    contentResolver.delete(ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id), null, null)
                }
            }
            val mimeType = if (fileName.endsWith(".cbz", true)) "application/vnd.comicbook+zip" else "application/octet-stream"
            val cv = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv)
                ?: throw Exception("Impossible de créer le fichier dans Téléchargements")
            contentResolver.openOutputStream(uri)?.use { out ->
                FileInputStream(File(filePath)).use { it.copyTo(out) }
            }
            "Téléchargements/$subFolder/$fileName"
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), subFolder).also { it.mkdirs() }
            File(filePath).copyTo(File(dir, fileName), overwrite = true)
            File(dir, fileName).absolutePath
        }
    }

    // ── listExportedFiles ──────────────────────────────────────────────────────

    private fun handleListExportedFiles(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(emptyList<Any>()); return
        }
        val files = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            MediaStore.Downloads._ID,
            MediaStore.Downloads.DISPLAY_NAME,
            MediaStore.Downloads.SIZE,
            MediaStore.Downloads.DATE_ADDED,
            MediaStore.Downloads.RELATIVE_PATH,
        )
        contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            projection,
            "${MediaStore.Downloads.RELATIVE_PATH} LIKE ? AND ${MediaStore.Downloads.DISPLAY_NAME} LIKE ?",
            arrayOf("Download/Inktoon/%", "%.cbz"),
            "${MediaStore.Downloads.DATE_ADDED} DESC"
        )?.use { c ->
            val idCol   = c.getColumnIndexOrThrow(MediaStore.Downloads._ID)
            val nameCol = c.getColumnIndexOrThrow(MediaStore.Downloads.DISPLAY_NAME)
            val sizeCol = c.getColumnIndexOrThrow(MediaStore.Downloads.SIZE)
            val dateCol = c.getColumnIndexOrThrow(MediaStore.Downloads.DATE_ADDED)
            val pathCol = c.getColumnIndexOrThrow(MediaStore.Downloads.RELATIVE_PATH)
            while (c.moveToNext()) {
                val id = c.getLong(idCol)
                val relativePath = c.getString(pathCol) ?: ""
                val subFolder = relativePath
                    .removePrefix("Download/Inktoon/")
                    .trimEnd('/')
                files.add(mapOf(
                    "id"        to id.toString(),
                    "name"      to (c.getString(nameCol) ?: ""),
                    "size"      to c.getLong(sizeCol),
                    "date"      to c.getLong(dateCol),
                    "subFolder" to subFolder,
                    "uri"       to ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id).toString(),
                ))
            }
        }
        result.success(files)
    }

    // ── transferToEReader ──────────────────────────────────────────────────────

    private fun handleTransferToEReader(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val fileUris  = (args?.get("fileUris")  as? List<*>)?.filterIsInstance<String>()
        val fileNames = (args?.get("fileNames") as? List<*>)?.filterIsInstance<String>()
        if (fileUris == null || fileNames == null) {
            result.error("MISSING_ARG", "fileUris and fileNames are required", null); return
        }
        pendingFileUris = fileUris
        pendingFileNames = fileNames
        pendingTransferResult = result
        folderPickerLauncher.launch(null)
    }

    private fun copyUriToTree(sourceUri: Uri, treeUri: Uri, fileName: String) {
        val treeDocId = DocumentsContract.getTreeDocumentId(treeUri)
        val parentDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, treeDocId)
        val mimeType = if (fileName.endsWith(".cbz", true)) "application/vnd.comicbook+zip" else "application/octet-stream"
        val newDocUri = DocumentsContract.createDocument(contentResolver, parentDocUri, mimeType, fileName)
            ?: throw Exception("Impossible de créer $fileName sur la liseuse")
        contentResolver.openInputStream(sourceUri)?.use { input ->
            contentResolver.openOutputStream(newDocUri)?.use { output ->
                input.copyTo(output)
            }
        }
    }

    // ── download notifications ────────────────────────────────────────────────

    private fun handleUpdateDownloadNotif(call: MethodCall, result: MethodChannel.Result) {
        val current = call.argument<Int>("current") ?: 0
        val total   = call.argument<Int>("total")   ?: 0
        val title   = call.argument<String>("title") ?: "Téléchargement en cours"
        val nm = NotificationManagerCompat.from(this)
        showProgress(nm, NOTIF_DOWNLOAD_ID, title, "Chapitre $current / $total", current, total)
        result.success(null)
    }

    private fun handleCancelDownloadNotif(result: MethodChannel.Result) {
        NotificationManagerCompat.from(this).cancel(NOTIF_DOWNLOAD_ID)
        result.success(null)
    }

    // ── getConnectedUsbDevices ─────────────────────────────────────────────────

    private fun handleGetUsbDevices(result: MethodChannel.Result) {
        try {
            val usbManager = getSystemService(USB_SERVICE) as UsbManager
            val devices = usbManager.deviceList.values.map { d ->
                mapOf(
                    "name"      to (d.productName ?: d.deviceName ?: "Appareil USB"),
                    "vendorId"  to d.vendorId,
                    "productId" to d.productId,
                )
            }
            result.success(devices)
        } catch (e: Exception) {
            result.success(emptyList<Any>())
        }
    }
}
