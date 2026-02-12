# HAProxy cannot do SOCKS5 — but here's every working alternative

**HAProxy does not support SOCKS5 upstream connections.** It supports only SOCKS4 (via the `socks4` server keyword added in v2.0), which lacks authentication and DNS-via-proxy capabilities that SOCKS5 provides. For your specific use case — forwarding TCP ports 2087 and 2052 through a SOCKS5 proxy at `127.0.0.1:1080` — GOST remains the most direct tool. However, several hybrid architectures can bring HAProxy into the picture if you need its load balancing, health checks, or stats dashboard. This guide covers every viable approach with production-ready configurations.

---

## Why HAProxy stops at SOCKS4

HAProxy added the `socks4` and `check-via-socks4` server keywords in **version 2.0** (June 2019), closing GitHub issue #82 ("Upstream socks proxy support"). The implementation covers only the SOCKS4 protocol because SOCKS4 is a simple connect-and-go protocol, while SOCKS5 requires a multi-step handshake with authentication negotiation — significantly more complex to integrate into HAProxy's event-driven architecture. No `socks5` keyword exists in any HAProxy version through the current 3.x branch, and no Lua script, plugin, or extension adds it.

**However, if your SOCKS5 proxy also accepts SOCKS4 connections** (many do, including SSH `-D` tunnels and some SMTP tunnel proxies), HAProxy's native `socks4` directive works perfectly. This is worth testing first since it's the cleanest solution. SOCKS4 limitations: no username/password authentication, no DNS resolution through the proxy (you must specify the foreign server by IP, not hostname), and no IPv6 support.

---

## Three production-ready architectures ranked

Each architecture below is complete with configs. Replace `FOREIGN_IP` with your actual foreign server IP throughout.

### Option A: HAProxy with native SOCKS4 (try this first)

This works only if your SOCKS5 proxy at `127.0.0.1:1080` also accepts SOCKS4 connections. Test it — if it works, this is the simplest and highest-performance solution.

**Install HAProxy:**
```bash
# Ubuntu 22.04+ (gets HAProxy 2.4+, sufficient for socks4 support)
sudo apt update && sudo apt install -y haproxy

# For latest LTS (3.0) via PPA:
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:vbernat/haproxy-3.0 -y
sudo apt update && sudo apt install -y haproxy

# Verify version (must be >= 2.0)
haproxy -v
```

**Complete configuration** (`/etc/haproxy/haproxy.cfg`):
```
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 50000
    tune.bufsize 16384
    spread-checks 5

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    option  redispatch
    retries 3
    timeout connect 10s
    timeout client  300s
    timeout server  300s
    timeout queue   30s
    maxconn 50000

listen stats
    bind 127.0.0.1:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s

listen tcp_2087
    bind *:2087
    mode tcp
    option tcplog
    server foreign FOREIGN_IP:2087 socks4 127.0.0.1:1080 check-via-socks4 check inter 10s fall 3 rise 2

listen tcp_2052
    bind *:2052
    mode tcp
    option tcplog
    server foreign FOREIGN_IP:2052 socks4 127.0.0.1:1080 check-via-socks4 check inter 10s fall 3 rise 2
```

**Validate and start:**
```bash
sudo haproxy -f /etc/haproxy/haproxy.cfg -c   # Must print "Configuration file is valid"
sudo systemctl enable haproxy
sudo systemctl restart haproxy
```

If connections fail with this config, your SOCKS proxy is SOCKS5-only — move to Option B or C.

### Option B: HAProxy → socat → SOCKS5 (best hybrid)

This chains HAProxy as the front-end listener with socat 1.8.x bridges that handle the SOCKS5 tunneling. You get HAProxy's health checks, stats, and connection management while socat handles the SOCKS5 protocol.

**Architecture:** `Client → HAProxy (:2087/:2052) → socat (127.0.0.1:12087/12052) → SOCKS5 (127.0.0.1:1080) → FOREIGN_IP:2087/2052`

**Install socat 1.8.x** (required for native SOCKS5 support):
```bash
# Check if repo version is 1.8.x+
apt-cache policy socat

# If 1.8.x+ is available:
sudo apt install -y socat

# Otherwise, build from source:
sudo apt install -y build-essential libssl-dev libreadline-dev
cd /tmp
wget http://www.dest-unreach.org/socat/download/socat-1.8.1.0.tar.gz
tar xzf socat-1.8.1.0.tar.gz
cd socat-1.8.1.0
./configure && make && sudo make install
socat -V | head -2   # Verify version
```

**Create socat systemd services:**

`/etc/systemd/system/socat-bridge-2087.service`:
```ini
[Unit]
Description=Socat SOCKS5 bridge for port 2087
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:12087,fork,reuseaddr,bind=127.0.0.1 SOCKS5-CONNECT:127.0.0.1:FOREIGN_IP:2087,socksport=1080
Restart=always
RestartSec=3
User=nobody
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

`/etc/systemd/system/socat-bridge-2052.service`:
```ini
[Unit]
Description=Socat SOCKS5 bridge for port 2052
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:12052,fork,reuseaddr,bind=127.0.0.1 SOCKS5-CONNECT:127.0.0.1:FOREIGN_IP:2052,socksport=1080
Restart=always
RestartSec=3
User=nobody
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

**HAProxy configuration** (`/etc/haproxy/haproxy.cfg`):
```
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 50000

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    retries 3
    timeout connect 5s
    timeout client  300s
    timeout server  300s

listen stats
    bind 127.0.0.1:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s

listen tcp_2087
    bind *:2087
    mode tcp
    option tcplog
    server socat_bridge 127.0.0.1:12087 check inter 10s fall 3 rise 2

listen tcp_2052
    bind *:2052
    mode tcp
    option tcplog
    server socat_bridge 127.0.0.1:12052 check inter 10s fall 3 rise 2
```

**Start everything:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now socat-bridge-2087 socat-bridge-2052
sudo haproxy -f /etc/haproxy/haproxy.cfg -c
sudo systemctl enable --now haproxy
```

### Option C: Standalone socat (simplest, no HAProxy)

If you don't need HAProxy's features (load balancing, stats, health checks), socat alone replaces GOST entirely:

```bash
# Port 2087
socat TCP-LISTEN:2087,fork,reuseaddr SOCKS5-CONNECT:127.0.0.1:FOREIGN_IP:2087,socksport=1080

# Port 2052
socat TCP-LISTEN:2052,fork,reuseaddr SOCKS5-CONNECT:127.0.0.1:FOREIGN_IP:2052,socksport=1080
```

Use the same systemd service pattern as Option B, but bind socat directly to `*:2087` and `*:2052` instead of the `127.0.0.1:12087/12052` local bridges.

---

## GOST vs HAProxy vs socat for this use case

For **TCP-through-SOCKS5 port forwarding** specifically, the tools differ sharply.

**GOST is purpose-built for this exact scenario.** Your existing command (`gost -L=tcp://:2087/FOREIGN_IP:2087 -F=socks5://127.0.0.1:1080`) handles SOCKS5 natively, supports proxy chaining, authentication, and both TCP and UDP forwarding in a single binary. GOST v3 (latest **v3.2.6**, November 2025) is actively maintained with YAML configuration support. The Go runtime makes it slightly heavier than C-based tools (~12MB binary) but still lightweight in practice.

**HAProxy excels at everything except SOCKS5.** Its event-driven C architecture delivers exceptional TCP throughput with minimal overhead (~2.6MB RAM). In TCP mode, it supports kernel-level splice() for zero-copy forwarding, comprehensive health checks, real-time stats, ACLs, and hot-reload without dropping connections. But without SOCKS5 support, it cannot be the sole solution here.

**socat 1.8.x** bridges the gap with native `SOCKS5-CONNECT`. It's lightweight and widely available but forks a new process per connection, making it less efficient than GOST's goroutine-based or HAProxy's event-driven model under high concurrency.

| Capability | GOST | HAProxy | socat 1.8.x |
|---|---|---|---|
| **Native SOCKS5 tunneling** | ✅ First-class | ❌ SOCKS4 only | ✅ Since 1.8.0 |
| **TCP forwarding performance** | Good | Exceptional | Moderate |
| **Concurrency model** | Goroutines | Event-driven | Fork per connection |
| **Health checks** | Basic | Advanced L4/L7 | None |
| **Stats/monitoring** | JSON logs | Full dashboard | None |
| **Production maturity** | Solid (tunneling community) | Industry standard | Solid (Unix staple) |
| **Config complexity** | Low (single CLI flag) | Medium | Low |

**Bottom line:** If GOST already works and you don't need HAProxy-specific features (load balancing, stats, health checks), there is **no advantage to switching to HAProxy** for this use case. GOST handles it in one line; HAProxy requires workarounds.

---

## HAProxy systemd service file

Ubuntu's `apt install haproxy` automatically installs this service file. For reference or manual installation:

```ini
# /etc/systemd/system/haproxy.service
[Unit]
Description=HAProxy Load Balancer
Documentation=man:haproxy(1)
After=network-online.target
Wants=network-online.target

[Service]
Environment="CONFIG=/etc/haproxy/haproxy.cfg" "PIDFILE=/run/haproxy.pid"
ExecStartPre=/usr/sbin/haproxy -f $CONFIG -c -q
ExecStart=/usr/sbin/haproxy -Ws -f $CONFIG -p $PIDFILE
ExecReload=/usr/sbin/haproxy -f $CONFIG -c -q
ExecReload=/bin/kill -USR2 $MAINPID
KillMode=mixed
Restart=always
RestartSec=5
Type=notify
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable haproxy
sudo systemctl start haproxy
```

---

## Verification and testing commands

**Validate configuration before every restart:**
```bash
sudo haproxy -f /etc/haproxy/haproxy.cfg -c
```

**Check listening ports:**
```bash
sudo ss -tlnp | grep -E '(haproxy|socat)'
# Expected: LISTEN on 0.0.0.0:2087, 0.0.0.0:2052
```

**Test TCP connectivity:**
```bash
# From the server itself
nc -zv 127.0.0.1 2087
nc -zv 127.0.0.1 2052

# From a remote machine
nc -zv YOUR_IRAN_SERVER_IP 2087
nc -zv YOUR_IRAN_SERVER_IP 2052
```

**Monitor HAProxy stats:**
```bash
# Via stats page (if configured)
curl http://127.0.0.1:8404/stats

# Via runtime socket
echo "show stat" | sudo socat stdio /run/haproxy/admin.sock
echo "show servers state" | sudo socat stdio /run/haproxy/admin.sock
```

**Check service health:**
```bash
sudo systemctl status haproxy
sudo journalctl -u haproxy -f --no-pager
# For socat bridges (Option B):
sudo systemctl status socat-bridge-2087 socat-bridge-2052
```

**End-to-end test (if port 2087 runs HTTPS/cPanel):**
```bash
curl -vk https://YOUR_IRAN_SERVER_IP:2087/
```

---

## Performance tuning for this scenario

For a TCP forwarding setup handling moderate traffic, add these **kernel parameters** to `/etc/sysctl.d/99-haproxy.conf`:

```bash
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.ip_local_port_range = 1024 65023
net.ipv4.tcp_fin_timeout = 30
net.core.netdev_max_backlog = 10000
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_syncookies = 1
net.core.somaxconn = 65535
```

```bash
sudo sysctl -p /etc/sysctl.d/99-haproxy.conf
```

**Raise file descriptor limits** in `/etc/security/limits.conf`:
```
haproxy  soft  nofile  65535
haproxy  hard  nofile  65535
```

**HAProxy-specific tuning tips:** In TCP mode, `timeout client` and `timeout server` should be equal (both set to **300s** for long-lived connections like SMTP/cPanel). The `maxconn` value of **50000** is conservative — each connection consumes roughly 32KB of RAM, so 50,000 connections ≈ 1.6GB. Adjust based on your server's available memory. HAProxy's TCP splice mode (enabled by default on Linux) provides zero-copy forwarding, which is the single biggest performance advantage over GOST and socat for raw throughput.

## Conclusion

**For your specific use case, GOST is the right tool.** It handles TCP-through-SOCKS5 in a single command with no workarounds. HAProxy's inability to speak SOCKS5 makes it a poor fit unless you need its load balancing or monitoring features — in which case, the HAProxy → socat → SOCKS5 chain (Option B) gives you both. If you want to move away from GOST for maintainability reasons, **socat 1.8.x is the most direct replacement** — same functionality, widely trusted, and trivial to wrap in systemd. The one scenario where HAProxy shines solo is if your SOCKS proxy accepts SOCKS4: test Option A first, and if it works, you get HAProxy's full feature set with zero additional components.