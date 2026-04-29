package com.example.inktoon

import android.content.ContentValues
import android.content.ContentUris
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "inktoon/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToDownloads") {
                    val filePath = call.argument<String>("filePath")
                    val fileName = call.argument<String>("fileName")
                    val subFolder = call.argument<String>("subFolder") ?: "Inktoon"
                    if (filePath == null || fileName == null) {
                        result.error("MISSING_ARG", "filePath and fileName are required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val savedPath = saveToDownloads(filePath, fileName, subFolder)
                        result.success(savedPath)
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun saveToDownloads(filePath: String, fileName: String, subFolder: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/$subFolder"

            // Delete existing file with same name to allow re-export
            val selection = "${MediaStore.Downloads.DISPLAY_NAME} = ? AND ${MediaStore.Downloads.RELATIVE_PATH} = ?"
            val selectionArgs = arrayOf(fileName, "$relativePath/")
            contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Downloads._ID),
                selection, selectionArgs, null
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID))
                    contentResolver.delete(
                        ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id),
                        null, null
                    )
                }
            }

            val mimeType = if (fileName.endsWith(".cbz", ignoreCase = true))
                "application/vnd.comicbook+zip"
            else
                "application/octet-stream"

            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
            }
            val uri = contentResolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues
            ) ?: throw Exception("Impossible de créer le fichier dans Téléchargements")

            contentResolver.openOutputStream(uri)?.use { out ->
                FileInputStream(File(filePath)).use { it.copyTo(out) }
            }

            "Téléchargements/$subFolder/$fileName"
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val targetDir = File(downloadsDir, subFolder).also { it.mkdirs() }
            File(filePath).copyTo(File(targetDir, fileName), overwrite = true)
            File(targetDir, fileName).absolutePath
        }
    }
}
