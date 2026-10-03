package app.shieldpal.shieldpal

import android.content.Context
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import java.io.ByteArrayInputStream

/**
 * Remote VPN: runs a WireGuard config that the USER supplied (for example a
 * free ProtonVPN server). All traffic then leaves through that server, so the
 * IP address and country change and sites blocked by the local provider open.
 * Only one VPN can be active on Android, so Shield (local DNS filter) and this
 * switch places automatically.
 */
object WgManager {
    private var backend: GoBackend? = null

    private val tunnel = object : Tunnel {
        override fun getName() = "shieldpal"
        override fun onStateChange(newState: Tunnel.State) {}
    }

    @Synchronized
    private fun backend(ctx: Context): GoBackend = backend ?: GoBackend(ctx.applicationContext).also { backend = it }

    /** Returns null on success, otherwise a readable error. Call off the main thread. */
    @Synchronized
    fun up(ctx: Context, config: String): String? = try {
        val cfg = Config.parse(ByteArrayInputStream(config.toByteArray(Charsets.UTF_8)))
        backend(ctx).setState(tunnel, Tunnel.State.UP, cfg)
        null
    } catch (e: Exception) {
        e.message ?: e.toString()
    }

    @Synchronized
    fun down(ctx: Context) {
        try {
            if (isUp(ctx)) backend(ctx).setState(tunnel, Tunnel.State.DOWN, null)
        } catch (e: Exception) {
        }
    }

    @Synchronized
    fun isUp(ctx: Context): Boolean = try {
        backend(ctx).getState(tunnel) == Tunnel.State.UP
    } catch (e: Exception) {
        false
    }
}
