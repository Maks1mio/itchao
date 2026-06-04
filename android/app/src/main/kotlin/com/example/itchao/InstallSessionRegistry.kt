package com.example.itchao

import java.util.concurrent.ConcurrentHashMap

/** Maps PackageInstaller session IDs to itch game metadata (callback extras may be stripped). */
object InstallSessionRegistry {
    data class SessionInfo(
        val gameId: Int,
        val packageName: String?,
    )

    private val sessions = ConcurrentHashMap<Int, SessionInfo>()

    fun register(sessionId: Int, gameId: Int, packageName: String?) {
        if (gameId <= 0) {
            return
        }
        sessions[sessionId] = SessionInfo(gameId, packageName)
    }

    fun lookup(sessionId: Int): SessionInfo? = sessions[sessionId]

    fun clear(sessionId: Int) {
        sessions.remove(sessionId)
    }
}
