package app.shieldpal.shieldpal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import org.json.JSONObject
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.DatagramChannel
import java.nio.channels.SelectionKey
import java.nio.channels.Selector
import java.nio.channels.SocketChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.random.Random

/**
 * Shield VPN - a real, on-device VPN.
 *
 * ALL of the phone's IPv4 traffic goes into the tunnel; ShieldPal forwards it
 * to the internet through its own protected sockets (a small user-space TCP /
 * UDP forwarder), so websites and apps keep working and Android shows a normal
 * working VPN (no "!" icon).
 *
 * What it adds on the way:
 *  - every DNS lookup is checked: dangerous domains get "not found"
 *  - the rest is sent to the DNS server the user picked (Cloudflare security /
 *    family / fast, Google, Quad9, AdGuard, OpenDNS) with automatic fallback
 *  - DNS answers are cached, which makes browsing faster
 *
 * Nothing leaves the phone except what the apps themselves send. There is no
 * ShieldPal server, and the VPN does not change your IP address or country.
 */
class ShieldVpnService : VpnService() {

    companion object {
        private const val TAG = "ShieldVpn"

        @Volatile
        var running = false
        const val ACTION_STOP = "app.shieldpal.STOP_VPN"
        private const val VPN_ADDRESS = "10.111.222.1"
        private const val VPN_DNS = "10.111.222.2"
        private val VPN_DNS_BYTES = byteArrayOf(10, 111, 222.toByte(), 2)
        private const val MSS = 1360
        private const val WINDOW = 65535

        /** id -> upstream servers. Keep ids in sync with lib/core/vpn_servers.dart. */
        private val PROVIDERS = mapOf(
            "cf_security" to listOf("1.1.1.2", "1.0.0.2"),
            "cf_family" to listOf("1.1.1.3", "1.0.0.3"),
            "cf_fast" to listOf("1.1.1.1", "1.0.0.1"),
            "google" to listOf("8.8.8.8", "8.8.4.4"),
            "quad9" to listOf("9.9.9.9", "149.112.112.112"),
            "adguard" to listOf("94.140.14.14", "94.140.15.15"),
            "opendns" to listOf("208.67.222.222", "208.67.220.220"),
        )

        // Known-bad or high-risk domain suffixes (extend as you like).
        private val blockSuffixes = setOf(
            "grabify.link", "iplogger.org", "iplogger.com", "2no.co", "yip.su", "blasze.com", "ps3cfw.com",
        )

        private const val FIN = 0x01
        private const val SYN = 0x02
        private const val RST = 0x04
        private const val PSH = 0x08
        private const val ACK = 0x10
    }

    private class Cached(val reply: ByteArray, val expires: Long)

    private var tun: ParcelFileDescriptor? = null
    private var out: FileOutputStream? = null
    private var loop: Thread? = null
    private val dnsPool = Executors.newFixedThreadPool(24)
    private val janitor = Executors.newSingleThreadScheduledExecutor()
    private val cache = ConcurrentHashMap<String, Cached>()
    private val tcp = ConcurrentHashMap<String, TcpSession>()
    private val udp = ConcurrentHashMap<String, UdpSession>()
    private var upstream: List<String> = PROVIDERS.getValue("cf_security")

    // ------------------------------------------------------------------ lifecycle

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopVpn()
            stopSelf()
            return START_NOT_STICKY
        }
        if (running) return START_STICKY
        val id = NativeStore.config(this).optString("vpnDns", "cf_security")
        val chosen = PROVIDERS[id] ?: PROVIDERS.getValue("cf_security")
        // Last-resort fallbacks so a blocked / slow server never breaks browsing.
        upstream = (chosen + PROVIDERS.getValue("cf_fast") + PROVIDERS.getValue("google")).distinct()
        cache.clear()
        val builder = Builder()
            .setSession("ShieldPal Shield")
            .addAddress(VPN_ADDRESS, 32)
            .addDnsServer(VPN_DNS)
            .addRoute("0.0.0.0", 0)
            .setMtu(1500)
            .setBlocking(true)
        tun = builder.establish() ?: return START_NOT_STICKY
        out = FileOutputStream(tun!!.fileDescriptor)
        goForeground()
        selector = Selector.open()
        running = true
        Log.d(TAG, "started, upstream=$upstream")
        Thread { selectorLoop() }.also { it.name = "shield-net"; it.start() }
        loop = Thread { runLoop() }.also { it.start() }
        janitor.scheduleWithFixedDelay({ sweep() }, 30, 30, TimeUnit.SECONDS)
        return START_STICKY
    }

    /** A small quiet notification keeps the VPN running when the phone tries to close background apps. */
    private fun goForeground() {
        try {
            val channel = "shield_vpn_status"
            if (Build.VERSION.SDK_INT >= 26) {
                val nm = getSystemService(NotificationManager::class.java)
                if (nm.getNotificationChannel(channel) == null) {
                    nm.createNotificationChannel(
                        NotificationChannel(channel, NativeStore.text(this, "txt_channel", "ShieldPal"), NotificationManager.IMPORTANCE_LOW)
                    )
                }
            }
            val open = PendingIntent.getActivity(
                this, 7001, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val n = androidx.core.app.NotificationCompat.Builder(this, channel)
                .setSmallIcon(R.drawable.ic_stat_shield)
                .setContentTitle("ShieldPal")
                .setContentText(NativeStore.text(this, "txt_vpn_running", "Shield VPN is protecting you"))
                .setOngoing(true)
                .setSilent(true)
                .setContentIntent(open)
                .build()
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(7001, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)
            } else {
                startForeground(7001, n)
            }
        } catch (e: Exception) {
            Log.w(TAG, "foreground not available: $e")
        }
    }

    override fun onRevoke() {
        stopVpn()
        super.onRevoke()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    private fun stopVpn() {
        running = false
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
        }
        loop?.interrupt()
        try {
            selector?.close()
        } catch (e: Exception) {
        }
        selector = null
        tcp.values.forEach { it.close() }
        tcp.clear()
        udp.values.forEach { it.close() }
        udp.clear()
        try {
            tun?.close()
        } catch (e: Exception) {
        }
        tun = null
    }

    private fun sweep() {
        val now = System.currentTimeMillis()
        tcp.entries.removeIf { (_, s) ->
            if (!s.connected && now - s.created > 10_000) s.fail() // server did not answer in time
            val dead = now - s.lastActive > 180_000 || s.closed
            if (dead) s.close()
            dead
        }
        udp.entries.removeIf { (_, s) ->
            val dead = now - s.lastActive > s.idleLimit || s.closed
            if (dead) s.close()
            dead
        }
    }

    // ------------------------------------------------------------------ main loop

    private fun runLoop() {
        val fd = tun?.fileDescriptor ?: return
        val input = FileInputStream(fd)
        val buf = ByteArray(32767)
        while (running) {
            val len = try {
                input.read(buf)
            } catch (e: Exception) {
                break
            }
            if (len <= 0) continue
            try {
                handlePacket(buf, len)
            } catch (e: Exception) {
                Log.w(TAG, "packet failed: $e")
            }
        }
    }

    private fun writeTun(p: ByteArray) {
        val o = out ?: return
        try {
            synchronized(o) { o.write(p) }
        } catch (e: Exception) {
        }
    }

    private fun handlePacket(buf: ByteArray, len: Int) {
        if (len < 20 || (buf[0].toInt() shr 4) != 4) return // IPv4 only
        val ihl = (buf[0].toInt() and 0x0f) * 4
        val proto = buf[9].toInt() and 0xff
        val total = u16(buf, 2).coerceAtMost(len)
        // fragments are not supported (our MSS keeps packets small)
        if ((u16(buf, 6) and 0x3fff) != 0) return
        val dst0 = buf[16].toInt() and 0xff
        if (dst0 >= 224) return // multicast / broadcast: ignore
        when (proto) {
            6 -> onTcp(buf.copyOf(total), ihl)
            17 -> onUdp(buf.copyOf(total), ihl)
        }
    }

    // ------------------------------------------------------------------ one selector thread for ALL sockets

    private interface Registrable {
        fun register(sel: Selector)
    }

    private var selector: Selector? = null
    private val pendingRegister = ConcurrentLinkedQueue<Registrable>()
    private val pendingInterest = ConcurrentLinkedQueue<TcpSession>()

    private fun wake() {
        selector?.wakeup()
    }

    private fun selectorLoop() {
        val sel = selector ?: return
        while (running) {
            try {
                sel.select(250)
                while (true) {
                    val r = pendingRegister.poll() ?: break
                    try {
                        r.register(sel)
                    } catch (e: Exception) {
                        Log.w(TAG, "register failed: $e")
                    }
                }
                while (true) {
                    val s = pendingInterest.poll() ?: break
                    s.applyInterest()
                }
                val it = sel.selectedKeys().iterator()
                while (it.hasNext()) {
                    val k = it.next()
                    it.remove()
                    if (!k.isValid) continue
                    when (val a = k.attachment()) {
                        is TcpSession -> try {
                            a.onKey(k)
                        } catch (e: Exception) {
                            a.fail()
                        }
                        is UdpSession -> try {
                            a.onKey(k)
                        } catch (e: Exception) {
                            a.close()
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "selector loop: $e")
            }
        }
    }

    // ------------------------------------------------------------------ UDP

    private fun onUdp(p: ByteArray, ihl: Int) {
        if (p.size < ihl + 8) return
        val srcPort = u16(p, ihl)
        val dstPort = u16(p, ihl + 2)
        val payload = p.copyOfRange(ihl + 8, p.size)
        val toVpnDns = p.copyOfRange(16, 20).contentEquals(VPN_DNS_BYTES)
        if (toVpnDns && dstPort == 53) {
            dnsPool.execute { handleDns(p, ihl, payload) }
            return
        }
        val dstIp = p.copyOfRange(16, 20)
        val srcIp = p.copyOfRange(12, 16)
        val key = "${ip(srcIp)}:$srcPort>${ip(dstIp)}:$dstPort"
        var s = udp[key]
        if (s == null || s.closed) {
            if (udp.size > 600) return
            s = UdpSession(srcIp, srcPort, dstIp, dstPort)
            if (!s.open()) return
            udp[key] = s
        }
        s.send(payload)
    }

    private inner class UdpSession(val srcIp: ByteArray, val srcPort: Int, val dstIp: ByteArray, val dstPort: Int) : Registrable {
        @Volatile var lastActive = System.currentTimeMillis()
        @Volatile var closed = false
        val idleLimit = if (dstPort == 53 || dstPort == 123) 20_000L else 90_000L
        private var ch: DatagramChannel? = null
        private val buf = ByteBuffer.allocate(65535)

        fun open(): Boolean = try {
            val c = DatagramChannel.open()
            c.configureBlocking(false)
            protect(c.socket())
            ch = c
            pendingRegister.add(this)
            wake()
            true
        } catch (e: Exception) {
            false
        }

        override fun register(sel: Selector) {
            ch?.register(sel, SelectionKey.OP_READ, this)
        }

        fun send(data: ByteArray) {
            lastActive = System.currentTimeMillis()
            try {
                ch?.send(ByteBuffer.wrap(data), InetSocketAddress(InetAddress.getByAddress(dstIp), dstPort))
            } catch (e: Exception) {
                close()
            }
        }

        fun onKey(k: SelectionKey) {
            if (!k.isReadable) return
            val c = ch ?: return
            while (true) {
                buf.clear()
                c.receive(buf) ?: break
                val n = buf.position()
                lastActive = System.currentTimeMillis()
                writeTun(buildUdp(dstIp, dstPort, srcIp, srcPort, buf.array(), n))
            }
        }

        fun close() {
            closed = true
            try {
                ch?.close()
            } catch (e: Exception) {
            }
        }
    }

    private fun buildUdp(srcIp: ByteArray, srcPort: Int, dstIp: ByteArray, dstPort: Int, data: ByteArray, len: Int): ByteArray {
        // Keep one datagram inside one IP packet (no fragmentation support).
        val n = minOf(len, 1472)
        val total = 28 + n
        val r = ByteArray(total)
        r[0] = 0x45
        put16(r, 2, total)
        r[6] = 0x40
        r[8] = 64
        r[9] = 17
        System.arraycopy(srcIp, 0, r, 12, 4)
        System.arraycopy(dstIp, 0, r, 16, 4)
        put16(r, 20, srcPort)
        put16(r, 22, dstPort)
        put16(r, 24, 8 + n)
        System.arraycopy(data, 0, r, 28, n)
        ipChecksum(r)
        return r
    }

    // ------------------------------------------------------------------ TCP

    private fun onTcp(p: ByteArray, ihl: Int) {
        if (p.size < ihl + 20) return
        val srcPort = u16(p, ihl)
        val dstPort = u16(p, ihl + 2)
        val seq = u32(p, ihl + 4)
        val ack = u32(p, ihl + 8)
        val hdr = ((p[ihl + 12].toInt() and 0xf0) shr 4) * 4
        val flags = p[ihl + 13].toInt() and 0xff
        val win = u16(p, ihl + 14)
        val srcIp = p.copyOfRange(12, 16)
        val dstIp = p.copyOfRange(16, 20)
        val key = "${ip(srcIp)}:$srcPort>${ip(dstIp)}:$dstPort"
        val dataOff = ihl + hdr
        val dataLen = (p.size - dataOff).coerceAtLeast(0)

        if (flags and SYN != 0 && flags and ACK == 0) {
            val old = tcp[key]
            if (old != null && !old.closed && old.synSeq == seq) return // retransmitted SYN
            old?.close()
            if (tcp.size > 1500) {
                sendRstFor(srcIp, srcPort, dstIp, dstPort, 0, seq + 1, true)
                return
            }
            val s = TcpSession(key, srcIp, srcPort, dstIp, dstPort, seq)
            // peer options: window scale
            var i = ihl + 20
            while (i < ihl + hdr) {
                val kind = p[i].toInt() and 0xff
                if (kind == 0) break
                if (kind == 1) {
                    i++
                    continue
                }
                if (i + 1 >= p.size) break
                val l = p[i + 1].toInt() and 0xff
                if (l < 2) break
                if (kind == 3 && l == 3) s.peerWs = (p[i + 2].toInt() and 0xff).coerceAtMost(14)
                i += l
            }
            s.peerWnd = win.toLong()
            if (!s.begin()) {
                sendRstFor(srcIp, srcPort, dstIp, dstPort, 0, seq + 1, true)
                return
            }
            tcp[key] = s
            return
        }
        val s = tcp[key]
        if (s == null) {
            // Unknown connection: tell the app to give up quickly.
            if (flags and RST == 0) {
                sendRstFor(srcIp, srcPort, dstIp, dstPort, if (flags and ACK != 0) ack else 0,
                    seq + dataLen + (if (flags and (SYN or FIN) != 0) 1 else 0), flags and ACK == 0)
            }
            return
        }
        s.onFromApp(flags, seq, ack, win, if (dataLen > 0) p.copyOfRange(dataOff, dataOff + dataLen) else null)
    }

    private inner class TcpSession(
        val key: String, val srcIp: ByteArray, val srcPort: Int, val dstIp: ByteArray, val dstPort: Int, val synSeq: Long,
    ) : Registrable {
        val created = System.currentTimeMillis()
        @Volatile var lastActive = created
        @Volatile var closed = false
        @Volatile var connected = false
        @Volatile var peerWnd = 65535L
        @Volatile var peerWs = 0

        // sequence numbers (all modulo 2^32, kept in Long)
        @Volatile var rcvNxt = (synSeq + 1) and 0xffffffffL   // next byte expected from the app
        @Volatile var ackNxt = rcvNxt                          // what we have confirmed to the app
        @Volatile var sndNxt = Random.nextLong(1, 0x7fffffffL)
        @Volatile var sndUna = sndNxt

        @Volatile var finSent = false
        @Volatile var finRcvd = false
        @Volatile var wantFinOut = false
        @Volatile var wantWrite = false
        @Volatile var wantResumeRead = false
        @Volatile var readBlocked = false
        @Volatile var remoteEof = false

        private var ch: SocketChannel? = null
        private var key0: SelectionKey? = null
        private val writeQ = ConcurrentLinkedQueue<ByteBuffer>()
        private val rbuf = ByteBuffer.allocate(MSS)
        private val toVpnDns = dstIp.contentEquals(VPN_DNS_BYTES)

        /** Called on the tun thread. Starts a non-blocking connect to the real server. */
        fun begin(): Boolean {
            return try {
                val c = SocketChannel.open()
                c.configureBlocking(false)
                protect(c.socket())
                c.socket().tcpNoDelay = true
                val target = if (toVpnDns) InetAddress.getByName(upstream.first()) else InetAddress.getByAddress(dstIp)
                val port = if (toVpnDns) 53 else dstPort
                connected = c.connect(InetSocketAddress(target, port))
                ch = c
                pendingRegister.add(this)
                wake()
                true
            } catch (e: Exception) {
                false
            }
        }

        override fun register(sel: Selector) {
            val c = ch ?: return
            if (closed) return
            key0 = c.register(sel, if (connected) SelectionKey.OP_READ else SelectionKey.OP_CONNECT, this)
            if (connected) onConnected()
        }

        private fun onConnected() {
            connected = true
            writeTun(buildTcp(this, SYN or ACK, sndNxt, rcvNxt, null, 0, true))
            sndNxt = (sndNxt + 1) and 0xffffffffL
        }

        fun onKey(k: SelectionKey) {
            val c = ch ?: return
            if (k.isValid && k.isConnectable) {
                if (c.finishConnect()) {
                    k.interestOps(SelectionKey.OP_READ)
                    onConnected()
                }
            }
            if (k.isValid && k.isReadable) readRemote(k, c)
            if (k.isValid && k.isWritable) writeRemote(k, c)
        }

        /** Remote -> app, never sending more than the app's receive window allows. */
        private fun readRemote(k: SelectionKey, c: SocketChannel) {
            var rounds = 0
            while (rounds++ < 16) {
                if (inflight() + MSS > window()) {
                    readBlocked = true
                    k.interestOps(k.interestOps() and SelectionKey.OP_READ.inv())
                    return
                }
                rbuf.clear()
                val n = c.read(rbuf)
                if (n < 0) {
                    remoteEof = true
                    k.interestOps(k.interestOps() and SelectionKey.OP_READ.inv())
                    if (!finSent) {
                        val seq = sndNxt
                        sndNxt = (sndNxt + 1) and 0xffffffffL
                        finSent = true
                        writeTun(buildTcp(this, FIN or ACK, seq, ackNxt, null, 0, false))
                    }
                    maybeFinish()
                    return
                }
                if (n == 0) return
                lastActive = System.currentTimeMillis()
                val seq = sndNxt
                sndNxt = (sndNxt + n) and 0xffffffffL
                writeTun(buildTcp(this, PSH or ACK, seq, ackNxt, rbuf.array(), n, false))
            }
        }

        /** App -> remote. ACKs are sent only after the bytes were really written (back-pressure). */
        private fun writeRemote(k: SelectionKey, c: SocketChannel) {
            while (true) {
                val b = writeQ.peek() ?: break
                val size = b.remaining()
                c.write(b)
                if (b.hasRemaining()) return // socket buffer full: wait for the next OP_WRITE
                writeQ.poll()
                ackNxt = (ackNxt + size) and 0xffffffffL
                lastActive = System.currentTimeMillis()
                sendAck()
            }
            k.interestOps(k.interestOps() and SelectionKey.OP_WRITE.inv())
            if (wantFinOut && writeQ.isEmpty()) {
                wantFinOut = false
                try {
                    c.shutdownOutput()
                } catch (_: Exception) {
                }
                ackNxt = (ackNxt + 1) and 0xffffffffL
                sendAck()
                maybeFinish()
            }
        }

        /** Selector thread: applies interest changes requested by the tun thread. */
        fun applyInterest() {
            val k = key0 ?: return
            if (!k.isValid) return
            var ops = k.interestOps()
            if (wantWrite) {
                ops = ops or SelectionKey.OP_WRITE
                wantWrite = false
            }
            if (wantResumeRead && connected && !remoteEof) {
                ops = ops or SelectionKey.OP_READ
                wantResumeRead = false
                readBlocked = false
            }
            k.interestOps(ops)
        }

        private fun inflight(): Long = (sndNxt - sndUna) and 0xffffffffL
        private fun window(): Long = (peerWnd shl peerWs).coerceIn(2048L, 262144L)

        /** Tun thread: a packet from the app for this connection. */
        fun onFromApp(flags: Int, seq: Long, ack: Long, win: Int, data: ByteArray?) {
            lastActive = System.currentTimeMillis()
            if (flags and RST != 0) {
                close()
                return
            }
            if (flags and ACK != 0) {
                // ack moves forward only
                if (diff(ack, sndUna) > 0 && diff(ack, sndNxt) <= 0) sndUna = ack
                peerWnd = win.toLong()
                if (readBlocked && inflight() + MSS <= window()) {
                    wantResumeRead = true
                    pendingInterest.add(this)
                    wake()
                }
            }
            if (data != null && data.isNotEmpty()) {
                if (diff(seq, rcvNxt) == 0L) {
                    rcvNxt = (rcvNxt + data.size) and 0xffffffffL
                    writeQ.add(ByteBuffer.wrap(data))
                    wantWrite = true
                    pendingInterest.add(this)
                    wake()
                } else {
                    // duplicate or out of order: repeat our ACK so the app resends in order
                    sendAck()
                }
            }
            if (flags and FIN != 0 && !finRcvd) {
                val finSeq = (seq + (data?.size ?: 0)) and 0xffffffffL
                if (finSeq == rcvNxt) {
                    finRcvd = true
                    rcvNxt = (rcvNxt + 1) and 0xffffffffL
                    wantFinOut = true
                    wantWrite = true
                    pendingInterest.add(this)
                    wake()
                }
            }
            if (finSent && finRcvd && sndUna == sndNxt) maybeFinish()
        }

        fun sendAck() {
            writeTun(buildTcp(this, ACK, sndNxt, ackNxt, null, 0, false))
        }

        /** Something went wrong with the remote side: reset the app's connection. */
        fun fail() {
            if (!closed) {
                writeTun(buildTcp(this, RST or ACK, sndNxt, ackNxt, null, 0, false))
                close()
            }
        }

        private fun maybeFinish() {
            if (finSent && finRcvd) janitor.schedule({ close() }, 4, TimeUnit.SECONDS)
        }

        fun close() {
            if (closed) return
            closed = true
            tcp.remove(key, this)
            try {
                key0?.cancel()
            } catch (_: Exception) {
            }
            try {
                ch?.close()
            } catch (_: Exception) {
            }
        }
    }

    private fun buildTcp(s: TcpSession, flags: Int, seq: Long, ack: Long, data: ByteArray?, len: Int, mss: Boolean): ByteArray {
        val th = if (mss) 24 else 20
        val total = 20 + th + len
        val r = ByteArray(total)
        r[0] = 0x45
        put16(r, 2, total)
        r[6] = 0x40
        r[8] = 64
        r[9] = 6
        System.arraycopy(s.dstIp, 0, r, 12, 4) // we speak as the remote server
        System.arraycopy(s.srcIp, 0, r, 16, 4)
        put16(r, 20, s.dstPort)
        put16(r, 22, s.srcPort)
        put32(r, 24, seq)
        put32(r, 28, if (flags and ACK != 0) ack else 0)
        r[32] = ((th / 4) shl 4).toByte()
        r[33] = flags.toByte()
        put16(r, 34, WINDOW)
        if (mss) {
            r[40] = 2
            r[41] = 4
            put16(r, 42, MSS)
        }
        if (data != null && len > 0) System.arraycopy(data, 0, r, 20 + th, len)
        tcpChecksum(r, th + len)
        ipChecksum(r)
        return r
    }

    private fun sendRstFor(srcIp: ByteArray, srcPort: Int, dstIp: ByteArray, dstPort: Int, seq: Long, ackV: Long, useAck: Boolean) {
        val r = ByteArray(40)
        r[0] = 0x45
        put16(r, 2, 40)
        r[6] = 0x40
        r[8] = 64
        r[9] = 6
        System.arraycopy(dstIp, 0, r, 12, 4)
        System.arraycopy(srcIp, 0, r, 16, 4)
        put16(r, 20, dstPort)
        put16(r, 22, srcPort)
        put32(r, 24, seq)
        put32(r, 28, ackV and 0xffffffffL)
        r[32] = 0x50
        r[33] = (if (useAck) (RST or ACK) else RST).toByte()
        tcpChecksum(r, 20)
        ipChecksum(r)
        writeTun(r)
    }

    // ------------------------------------------------------------------ DNS (filter + choice of server)

    private fun handleDns(p: ByteArray, ihl: Int, dns: ByteArray) {
        try {
            val host = queryName(dns)
            val reply: ByteArray = if (host != null && shouldBlock(host)) {
                logBlock(host)
                nxdomain(dns)
            } else {
                resolve(dns) ?: servfail(dns)
            }
            if (host != null && isSinkholed(reply)) logBlock(host)
            writeTun(buildDnsReply(p, ihl, fitUdp(reply)))
        } catch (e: Exception) {
            Log.w(TAG, "dns failed: $e")
        }
    }

    private fun shouldBlock(host: String): Boolean {
        val h = host.lowercase()
        if (blockSuffixes.any { h == it || h.endsWith(".$it") }) return true
        // Only block heuristics when they are very sure, to avoid breaking real sites.
        return ScamHeuristics.scoreUrl("https://$h/") >= 70
    }

    private fun queryName(dns: ByteArray): String? {
        if (dns.size < 13) return null
        val sb = StringBuilder()
        var i = 12
        while (i < dns.size) {
            val l = dns[i].toInt() and 0xff
            if (l == 0) break
            if (l and 0xc0 != 0 || i + l >= dns.size) return null
            if (sb.isNotEmpty()) sb.append('.')
            sb.append(String(dns, i + 1, l, Charsets.US_ASCII))
            i += l + 1
        }
        return sb.toString().ifEmpty { null }
    }

    /** end of the first question (offset just after QTYPE+QCLASS), or -1 */
    private fun questionEnd(q: ByteArray): Int {
        var i = 12
        while (i < q.size && q[i].toInt() != 0) i += (q[i].toInt() and 0xff) + 1
        val end = i + 5
        return if (end <= q.size) end else -1
    }

    private fun nxdomain(q: ByteArray): ByteArray = errorReply(q, 3)
    private fun servfail(q: ByteArray): ByteArray = errorReply(q, 2)

    private fun errorReply(q: ByteArray, rcode: Int): ByteArray {
        val end = questionEnd(q).let { if (it < 0) q.size else it }
        val r = q.copyOf(end)
        r[5] = 1
        r[2] = (0x81).toByte()
        r[3] = (0x80 or rcode).toByte()
        for (k in 6..11) r[k] = 0
        return r
    }

    private fun fitUdp(reply: ByteArray): ByteArray {
        if (reply.size <= 1400) return reply
        val end = questionEnd(reply).let { if (it < 0) 12 else it }
        val r = reply.copyOf(end)
        r[2] = (r[2].toInt() or 0x02).toByte() // TC: the app retries over TCP, which we forward
        for (k in 6..11) r[k] = 0
        return r
    }

    /** Cloudflare 1.1.1.2 answers 0.0.0.0 for domains it blocks. */
    private fun isSinkholed(reply: ByteArray): Boolean {
        for (i in 12 until reply.size - 14) {
            if (reply[i].toInt() == 0 && reply[i + 1].toInt() == 1 && reply[i + 2].toInt() == 0 && reply[i + 3].toInt() == 1) {
                val rdlen = ((reply[i + 8].toInt() and 0xff) shl 8) or (reply[i + 9].toInt() and 0xff)
                if (rdlen == 4 && i + 13 < reply.size &&
                    reply[i + 10].toInt() == 0 && reply[i + 11].toInt() == 0 && reply[i + 12].toInt() == 0 && reply[i + 13].toInt() == 0
                ) return true
            }
        }
        return false
    }

    private fun resolve(q: ByteArray): ByteArray? {
        val end = questionEnd(q)
        val key = if (end > 12) String(q, 12, end - 12, Charsets.ISO_8859_1) else null
        val now = System.currentTimeMillis()
        if (key != null) {
            val c = cache[key]
            if (c != null && c.expires > now) {
                val r = c.reply.copyOf()
                r[0] = q[0]
                r[1] = q[1]
                return r
            }
        }
        val r = forwardDns(q) ?: return null
        if (key != null && (r[3].toInt() and 0x0f) == 0 && r.size > 12) {
            if (cache.size > 800) cache.clear()
            cache[key] = Cached(r, now + 45_000)
        }
        return r
    }

    private fun forwardDns(q: ByteArray): ByteArray? {
        for (server in upstream) {
            try {
                DatagramSocket().use { s ->
                    protect(s)
                    s.soTimeout = 2500
                    s.send(DatagramPacket(q, q.size, InetAddress.getByName(server), 53))
                    val b = ByteArray(4096)
                    val resp = DatagramPacket(b, b.size)
                    s.receive(resp)
                    return b.copyOf(resp.length)
                }
            } catch (e: Exception) {
                Log.d(TAG, "upstream $server failed: $e")
            }
        }
        return null
    }

    private fun buildDnsReply(req: ByteArray, ihl: Int, dns: ByteArray): ByteArray {
        val total = 28 + dns.size
        val r = ByteArray(total)
        r[0] = 0x45
        put16(r, 2, total)
        r[6] = 0x40
        r[8] = 64
        r[9] = 17
        System.arraycopy(req, 16, r, 12, 4)
        System.arraycopy(req, 12, r, 16, 4)
        r[20] = req[ihl + 2]
        r[21] = req[ihl + 3]
        r[22] = req[ihl]
        r[23] = req[ihl + 1]
        put16(r, 24, 8 + dns.size)
        System.arraycopy(dns, 0, r, 28, dns.size)
        ipChecksum(r)
        return r
    }

    private fun logBlock(host: String) {
        NativeStore.incBlocked(this)
        if (!NativeStore.firstTime("dns|$host")) return
        val now = System.currentTimeMillis()
        val t = JSONObject()
            .put("id", "dns_${now}_${host.hashCode()}")
            .put("time", now)
            .put("kind", "dns")
            .put("app", "Shield VPN")
            .put("chat", "")
            .put("text", host)
            .put("url", host)
            .put("score", 80)
        NativeStore.addThreat(this, t)
        MainActivity.sendThreat(t.toString())
    }

    // ------------------------------------------------------------------ byte helpers

    private fun ip(b: ByteArray) = "${b[0].toInt() and 0xff}.${b[1].toInt() and 0xff}.${b[2].toInt() and 0xff}.${b[3].toInt() and 0xff}"
    private fun u16(b: ByteArray, o: Int) = ((b[o].toInt() and 0xff) shl 8) or (b[o + 1].toInt() and 0xff)
    private fun u32(b: ByteArray, o: Int): Long =
        ((b[o].toLong() and 0xff) shl 24) or ((b[o + 1].toLong() and 0xff) shl 16) or
            ((b[o + 2].toLong() and 0xff) shl 8) or (b[o + 3].toLong() and 0xff)

    private fun put16(b: ByteArray, o: Int, v: Int) {
        b[o] = (v shr 8).toByte()
        b[o + 1] = v.toByte()
    }

    private fun put32(b: ByteArray, o: Int, v: Long) {
        b[o] = (v shr 24).toByte()
        b[o + 1] = (v shr 16).toByte()
        b[o + 2] = (v shr 8).toByte()
        b[o + 3] = v.toByte()
    }

    /** signed difference a - b on 32-bit sequence numbers */
    private fun diff(a: Long, b: Long): Long = ((a - b).toInt()).toLong()

    private fun ipChecksum(r: ByteArray) {
        r[10] = 0
        r[11] = 0
        var sum = 0L
        for (i in 0 until 20 step 2) sum += ((r[i].toInt() and 0xff) shl 8) or (r[i + 1].toInt() and 0xff)
        while (sum shr 16 != 0L) sum = (sum and 0xffff) + (sum shr 16)
        val cs = (sum.inv() and 0xffff).toInt()
        put16(r, 10, cs)
    }

    /** TCP checksum over the pseudo header + [tcpLen] bytes starting at offset 20 */
    private fun tcpChecksum(r: ByteArray, tcpLen: Int) {
        r[36] = 0
        r[37] = 0
        var sum = 0L
        for (i in 12 until 20 step 2) sum += ((r[i].toInt() and 0xff) shl 8) or (r[i + 1].toInt() and 0xff)
        sum += 6 + tcpLen
        var i = 20
        val end = 20 + tcpLen
        while (i + 1 < end) {
            sum += ((r[i].toInt() and 0xff) shl 8) or (r[i + 1].toInt() and 0xff)
            i += 2
        }
        if (i < end) sum += (r[i].toInt() and 0xff) shl 8
        while (sum shr 16 != 0L) sum = (sum and 0xffff) + (sum shr 16)
        put16(r, 36, (sum.inv() and 0xffff).toInt())
    }
}
