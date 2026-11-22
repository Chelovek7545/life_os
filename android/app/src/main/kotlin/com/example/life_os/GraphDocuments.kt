package com.example.life_os

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStreamReader
import java.util.UUID

internal class GraphDocuments(private val activity: Activity, messenger: BinaryMessenger) {
    private val resolver = activity.contentResolver
    private val picker = MethodChannel(messenger, "pulse/graph_folder_picker")
    private val files = MethodChannel(
        messenger, "pulse/graph_files", io.flutter.plugin.common.StandardMethodCodec.INSTANCE,
        messenger.makeBackgroundTaskQueue(),
    )
    private var pendingPick: MethodChannel.Result? = null

    init {
        picker.setMethodCallHandler { call, result ->
            when {
                call.method != "pickFolder" -> result.notImplemented()
                pendingPick != null -> result.error("busy", "Диалог выбора папки уже открыт.", null)
                else -> {
                    pendingPick = result
                    try {
                        activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(grantFlags or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        }, requestCode)
                    } catch (error: Exception) {
                        pendingPick = null
                        result.error("folder_picker", error.localizedMessage, null)
                    }
                }
            }
        }
        files.setMethodCallHandler { call, result ->
            try {
                result.success(operate(call))
            } catch (error: SecurityException) {
                result.error("folder_access", "Нет доступа к папке. Выберите её снова в настройках графа.", null)
            } catch (error: Exception) {
                result.error("folder_operation", error.localizedMessage, null)
            }
        }
    }

    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != requestCode) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val tree = data?.data
        if (code != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return true
        }
        try {
            val flags = data.flags and grantFlags
            if (flags != grantFlags || !DocumentsContract.isTreeUri(tree)) {
                throw IOException("Для этой папки требуется доступ на чтение и запись.")
            }
            resolver.takePersistableUriPermission(tree, flags)
            val id = DocumentsContract.getTreeDocumentId(tree)
            val name = id.substringAfterLast('/').substringAfterLast(':')
            result.success(mapOf("uri" to tree.toString(), "name" to name.ifEmpty { "Выбранная папка" }))
        } catch (error: Exception) {
            result.error("folder_access", error.localizedMessage, null)
        }
        return true
    }

    fun dispose() {
        pendingPick?.success(null)
        pendingPick = null
        picker.setMethodCallHandler(null)
        files.setMethodCallHandler(null)
    }

    private data class Entry(val uri: Uri, val name: String, val mime: String, val modifiedAt: Long) {
        val type get() = if (mime == Document.MIME_TYPE_DIR) "directory" else "file"
    }

    private class NameCollision(name: String) : IOException("Файл «$name» уже существует.")

    private fun operate(call: MethodCall): Any? {
        val tree = Uri.parse(requireNotNull(call.argument<String>("tree")))
        if (!resolver.persistedUriPermissions.any { it.uri == tree && it.isReadPermission && it.isWritePermission }) {
            throw SecurityException("Folder permission was revoked")
        }
        val parts = requireNotNull(call.argument<List<String>>("parts"))
        require(parts.all(::validName)) { "Недопустимый путь внутри папки." }
        val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        return when (call.method) {
            "type" -> resolve(root, parts)?.type ?: "missing"
            "list" -> children(requireEntry(root, parts).uri).map {
                mapOf("name" to it.name, "type" to it.type, "modifiedAt" to it.modifiedAt)
            }
            "read" -> resolve(root, parts)?.let(::read)
            "createDirectory" -> {
                createDirectories(root, parts)
                null
            }
            "writeNew" -> {
                val parent = requireEntry(root, parts.dropLast(1)).uri
                writeNew(parent, parts.last(), requireNotNull(call.argument<String>("content")))
                null
            }
            "replace" -> replace(
                requireEntry(root, parts.dropLast(1)).uri,
                parts.last(),
                requireNotNull(call.argument<String>("content")),
                call.argument<String>("expected"),
            )
            "delete" -> {
                val entry = requireEntry(root, parts)
                if (entry.type != "file" || !DocumentsContract.deleteDocument(resolver, entry.uri)) {
                    throw IOException("Не удалось удалить файл «${entry.name}».")
                }
                null
            }
            else -> throw IllegalArgumentException("Неизвестная операция с документом.")
        }
    }

    private fun validName(name: String): Boolean =
        name.isNotEmpty() && name != "." && name != ".." && '/' !in name && '\\' !in name && '\u0000' !in name

    private fun children(parent: Uri): List<Entry> {
        val query = DocumentsContract.buildChildDocumentsUriUsingTree(parent, DocumentsContract.getDocumentId(parent))
        return resolver.query(query, columns, null, null, null)?.use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    val name = cursor.getString(1)
                    if (validName(name)) add(Entry(
                        DocumentsContract.buildDocumentUriUsingTree(parent, cursor.getString(0)),
                        name, cursor.getString(2), cursor.getLong(3),
                    ))
                }
            }
        } ?: throw IOException("Не удалось открыть выбранную папку.")
    }

    private fun child(parent: Uri, name: String): Entry? {
        val matches = children(parent).filter { it.name == name }
        if (matches.size > 1) throw IOException("В папке несколько файлов с именем «$name».")
        return matches.singleOrNull()
    }

    private fun resolve(root: Uri, parts: List<String>): Entry? {
        var entry = resolver.query(root, columns, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) Entry(root, cursor.getString(1), cursor.getString(2), cursor.getLong(3)) else null
        } ?: throw IOException("Выбранная папка недоступна.")
        for (part in parts) {
            if (entry.type != "directory") throw IOException("«${entry.name}» не является папкой.")
            entry = child(entry.uri, part) ?: return null
        }
        return entry
    }

    private fun requireEntry(root: Uri, parts: List<String>): Entry =
        resolve(root, parts) ?: throw IOException("Файл или папка «${parts.lastOrNull().orEmpty()}» недоступны.")

    private fun createDirectories(root: Uri, parts: List<String>) {
        var parent = requireEntry(root, emptyList()).uri
        for (part in parts) {
            val entry = child(parent, part)
            parent = if (entry == null) {
                val created = DocumentsContract.createDocument(resolver, parent, Document.MIME_TYPE_DIR, part)
                    ?: throw IOException("Не удалось создать папку «$part».")
                val result = child(parent, part)
                if (result?.uri != created) {
                    runCatching { DocumentsContract.deleteDocument(resolver, created) }
                    throw IOException("Имя папки «$part» занято или было изменено системой.")
                }
                created
            } else {
                if (entry.type != "directory") throw IOException("«$part» не является папкой.")
                entry.uri
            }
        }
    }

    private fun read(entry: Entry): String {
        if (entry.type != "file") throw IOException("«${entry.name}» не является файлом.")
        return resolver.openInputStream(entry.uri)?.use { input ->
            InputStreamReader(input, Charsets.UTF_8.newDecoder()).buffered().readText()
        }
            ?: throw IOException("Не удалось прочитать файл «${entry.name}».")
    }

    private fun write(uri: Uri, content: String) {
        val descriptor = resolver.openFileDescriptor(uri, "rw") ?: throw IOException("Не удалось открыть файл на запись.")
        ParcelFileDescriptor.AutoCloseOutputStream(descriptor).use { output ->
            output.write(content.toByteArray(Charsets.UTF_8))
            output.channel.truncate(output.channel.position())
            output.fd.sync()
        }
    }

    private fun writeNew(parent: Uri, name: String, content: String) {
        if (child(parent, name) != null) throw NameCollision(name)
        val temporary = DocumentsContract.createDocument(resolver, parent, "application/octet-stream", ".pulse-${UUID.randomUUID()}.tmp")
            ?: throw IOException("Не удалось создать временный файл для «$name».")
        var owned = temporary
        try {
            write(temporary, content)
            if (child(parent, name) != null) throw NameCollision(name)
            owned = DocumentsContract.renameDocument(resolver, temporary, name)
                ?: throw IOException("Не удалось сохранить файл «$name».")
            val saved = child(parent, name)
            if (saved != null && saved.uri != owned) throw NameCollision(name)
            if (saved == null) throw IOException("Система изменила имя файла «$name».")
        } catch (error: Exception) {
            runCatching { DocumentsContract.deleteDocument(resolver, owned) }
            throw error
        }
    }

    private fun replace(parent: Uri, name: String, content: String, expected: String?): Boolean {
        val original = child(parent, name)
        if (original?.let(::read) != expected) return false
        if (original == null) {
            return try {
                writeNew(parent, name, content)
                true
            } catch (_: NameCollision) {
                false
            }
        }
        if (content == expected) return true
        // The document provider does not expose an atomic overwrite. Keep the
        // previous revision until its replacement has been flushed to disk.
        val recoveryName = ".pulse-previous-${UUID.randomUUID()}-$name"
        writeNew(parent, recoveryName, expected!!)
        val recovery = requireNotNull(child(parent, recoveryName))
        val current = child(parent, name)
        if (current?.uri != original.uri || read(current) != expected) {
            runCatching { DocumentsContract.deleteDocument(resolver, recovery.uri) }
            return false
        }
        try {
            write(current.uri, content)
        } catch (error: Exception) {
            throw IOException("Запись «$name» прервалась. Предыдущая версия: $recoveryName. ${error.localizedMessage}", error)
        }
        runCatching { DocumentsContract.deleteDocument(resolver, recovery.uri) }
        return true
    }

    private companion object {
        const val requestCode = 4839
        const val grantFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        val columns = arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_MIME_TYPE, Document.COLUMN_LAST_MODIFIED)
    }
}
