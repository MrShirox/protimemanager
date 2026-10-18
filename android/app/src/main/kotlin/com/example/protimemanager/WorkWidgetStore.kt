package com.example.protimemanager

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId

class WidgetException(message: String) : Exception(message)

data class WidgetPause(
    val start: Long,
    val end: Long?,
    val deduction: Int?,
    val scheduled: Boolean
) {
    fun activeAt(now: Long) = deduction == null && start <= now && (end == null || end > now)
}

/** Mirror of the Dart ChronoSession, limited to what the widget needs. */
data class WidgetSession(
    val id: Long,
    val revision: Int,
    val start: Long,
    val end: Long?,
    val pauseMinutes: Int,
    val storedPauses: List<WidgetPause>
) {
    val running get() = end == null

    /** Old sessions kept only a pause total: place it at the start, like the app. */
    val pauses: List<WidgetPause>
        get() = if (storedPauses.isEmpty() && pauseMinutes > 0)
            listOf(WidgetPause(start, minOf(start + pauseMinutes * 60_000L, end ?: Long.MAX_VALUE), null, false))
        else storedPauses

    fun pausedAt(now: Long) = running && pauses.any { it.activeAt(now) }

    fun deductedMinutes() = pauses.sumOf { it.deduction ?: 0 }

    /** Same rules as ChronoSession.workedDuration in lib/models/chrono_entry.dart. */
    fun worked(now: Long, from: Long? = null, to: Long? = null): Long {
        var a = start
        var b = end ?: now
        if (from != null && from > a) a = from
        if (to != null && to < b) b = to
        if (b <= a) return 0
        val intervals = pauses.filter { it.deduction == null }
            .map { maxOf(it.start, a) to minOf(it.end ?: now, b) }
            .filter { it.second > it.first }
            .sortedBy { it.first }
        var deducted = 0L
        var lastStart: Long? = null
        var lastEnd: Long? = null
        for ((s, e) in intervals) {
            if (lastEnd == null || s > lastEnd) {
                if (lastEnd != null) deducted += lastEnd - lastStart!!
                lastStart = s
                lastEnd = e
            } else if (e > lastEnd) {
                lastEnd = e
            }
        }
        if (lastEnd != null) deducted += lastEnd - lastStart!!
        for (p in pauses.filter { it.deduction != null }) {
            if ((from == null || p.start >= from) && (to == null || p.start < to)) {
                deducted += p.deduction!! * 60_000L
            }
        }
        return (b - a) - deducted
    }
}

data class WidgetSnapshot(val active: WidgetSession?, val last: WidgetSession?)

/** Reads and writes the same tables as lib/services/work_sessions.dart. */
class WorkWidgetStore(private val context: Context) {

    private fun <T> open(write: Boolean, block: (SQLiteDatabase) -> T): T {
        val file = context.getDatabasePath("protimemanager.db")
        if (!file.exists()) throw WidgetException("Ouvre ProTimeManager une première fois.")
        val db = SQLiteDatabase.openDatabase(file.path, null,
            if (write) SQLiteDatabase.OPEN_READWRITE else SQLiteDatabase.OPEN_READONLY)
        try {
            if (db.version < 8) throw WidgetException("Ouvre ProTimeManager pour mettre à jour.")
            if (!write) return block(db)
            db.beginTransaction()
            try {
                val result = block(db)
                db.setTransactionSuccessful()
                return result
            } finally {
                db.endTransaction()
            }
        } finally {
            db.close()
        }
    }

    fun snapshot(): WidgetSnapshot = open(false) { db ->
        val sessions = read(db)
        WidgetSnapshot(activeOf(sessions), sessions.lastOrNull())
    }

    fun start() = open(true) { db ->
        val now = System.currentTimeMillis()
        val sessions = read(db)
        if (activeOf(sessions) != null) return@open
        if (sessions.any { it.start > now || (it.end ?: now) > now }) {
            throw WidgetException("Une session est dans le futur. Corrige-la dans le planning.")
        }
        db.insertOrThrow("chrono_sessions", null, ContentValues().apply {
            put("jour", dayKey(now))
            put("startTime", iso(now))
            putNull("endTime")
            put("pauseMinutes", 0)
            put("isActive", 1)
            put("revision", 1)
        })
    }

    fun stop() = open(true) { db ->
        val now = System.currentTimeMillis()
        val current = activeOf(read(db)) ?: return@open
        if (now < current.start) throw WidgetException("Le début de la session est dans le futur.")
        val pauses = current.pauses.map {
            if (it.activeAt(now)) it.copy(end = now, scheduled = false) else it
        }
        writePauses(db, current, pauses)
        db.update("chrono_sessions", ContentValues().apply {
            put("endTime", iso(now))
            put("isActive", 0)
            put("pauseMinutes", totalMinutes(pauses))
            put("revision", current.revision + 1)
        }, "id = ?", arrayOf(current.id.toString()))
    }

    fun pause(minutes: Int) = open(true) { db ->
        if (minutes !in listOf(20, 30, 45, 50, 60)) throw WidgetException("Durée de pause invalide.")
        val now = System.currentTimeMillis()
        val current = activeOf(read(db)) ?: return@open
        if (current.pausedAt(now)) return@open
        val pauses = current.pauses + WidgetPause(now, now, minutes, false)
        val updated = current.copy(storedPauses = pauses)
        val today = startOfDay(now)
        if (updated.worked(now, today, nextDay(now)) < 0) {
            throw WidgetException("Pause trop longue : pas assez de temps travaillé aujourd'hui.")
        }
        writePauses(db, current, pauses)
        db.update("chrono_sessions", ContentValues().apply {
            put("pauseMinutes", totalMinutes(pauses))
            put("revision", current.revision + 1)
        }, "id = ?", arrayOf(current.id.toString()))
    }

    private fun activeOf(sessions: List<WidgetSession>): WidgetSession? {
        val active = sessions.filter { it.running }
        if (active.size > 1) {
            throw WidgetException("Plusieurs sessions sont actives. Corrige-les dans le planning.")
        }
        return active.firstOrNull()
    }

    private fun read(db: SQLiteDatabase): List<WidgetSession> {
        val pausesBySession = HashMap<Long, MutableList<WidgetPause>>()
        db.rawQuery(
            "SELECT sessionId, startTime, endTime, deductionMinutes, scheduled FROM pause_plages " +
                "WHERE startTime IS NOT NULL ORDER BY startTime ASC, id ASC", null
        ).use { c ->
            while (c.moveToNext()) {
                pausesBySession.getOrPut(c.getLong(0)) { mutableListOf() }.add(WidgetPause(
                    start = parse(c.getString(1)),
                    end = if (c.isNull(2)) null else parse(c.getString(2)),
                    deduction = if (c.isNull(3)) null else c.getInt(3),
                    scheduled = !c.isNull(4) && c.getInt(4) == 1
                ))
            }
        }
        val sessions = mutableListOf<WidgetSession>()
        db.rawQuery(
            "SELECT id, revision, startTime, endTime, pauseMinutes FROM chrono_sessions", null
        ).use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0)
                sessions += WidgetSession(
                    id = id,
                    revision = if (c.isNull(1)) 0 else c.getInt(1),
                    start = parse(c.getString(2)),
                    end = if (c.isNull(3)) null else parse(c.getString(3)),
                    pauseMinutes = if (c.isNull(4)) 0 else c.getInt(4),
                    storedPauses = pausesBySession[id]?.sortedBy { it.start } ?: emptyList()
                )
            }
        }
        return sessions.sortedBy { it.start }
    }

    private fun writePauses(db: SQLiteDatabase, session: WidgetSession, pauses: List<WidgetPause>) {
        db.delete("pause_plages", "sessionId = ?", arrayOf(session.id.toString()))
        for (p in pauses) {
            db.insertOrThrow("pause_plages", null, ContentValues().apply {
                put("sessionId", session.id)
                put("scheduled", if (p.scheduled) 1 else 0)
                if (p.deduction == null) putNull("deductionMinutes") else put("deductionMinutes", p.deduction)
                put("jour", dayKey(p.start))
                put("startMinutes", minutesOfDay(p.start))
                put("endMinutes", if (p.end == null) -1 else minutesOfDay(p.end))
                put("startTime", iso(p.start))
                if (p.end == null) putNull("endTime") else put("endTime", iso(p.end))
            })
        }
    }

    private fun totalMinutes(pauses: List<WidgetPause>): Int =
        (pauses.sumOf { p -> p.deduction?.let { it * 60_000L } ?: ((p.end ?: p.start) - p.start) } / 60_000L).toInt()

    private val zone get() = ZoneId.systemDefault()
    private fun local(ms: Long) = Instant.ofEpochMilli(ms).atZone(zone)
    private fun dayKey(ms: Long) = local(ms).toLocalDate().toString()
    private fun minutesOfDay(ms: Long) = local(ms).let { it.hour * 60 + it.minute }
    private fun startOfDay(ms: Long) = local(ms).toLocalDate().atStartOfDay(zone).toInstant().toEpochMilli()
    private fun nextDay(ms: Long) = local(ms).toLocalDate().plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()

    /** Matches Dart's DateTime.toUtc().toIso8601String() closely enough for DateTime.parse. */
    private fun iso(ms: Long) = Instant.ofEpochMilli(ms).toString()

    /** Accepts UTC ("…Z"), offset, or local timestamps as written by older versions. */
    private fun parse(raw: String): Long {
        val s = raw.trim().replace(' ', 'T')
        return try {
            OffsetDateTime.parse(s).toInstant().toEpochMilli()
        } catch (_: Exception) {
            try {
                LocalDateTime.parse(s).atZone(zone).toInstant().toEpochMilli()
            } catch (_: Exception) {
                LocalDate.parse(s.take(10)).atStartOfDay(zone).toInstant().toEpochMilli()
            }
        }
    }
}
