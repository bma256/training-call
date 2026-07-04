// Minimal WebRTC signaling server.
//
// What this does NOT do: it never sees or touches video/audio. Its only job
// is to relay a handful of small JSON messages (offer/answer/ICE candidates)
// so two browsers can find each other. Once that handshake is done, video
// and audio flow directly between the two devices (or via STUN/TURN if
// needed for NAT traversal) — this server is out of the path entirely.
//
// Rooms are capped at 2 peers, which matches the one-trainer-one-client use
// case this was built for.
//
// ===== HEARTBEAT MODULE =====================================================
// Problem this solves: if a connection dies without a clean close (Wi-Fi
// drop, phone locking, tab backgrounded and killed by the OS, etc.), the
// server's in-memory room can be left thinking someone is still there —
// even though the browser is long gone. The next person to try to join
// then gets an incorrect "Call already in progress" until the whole
// service is restarted.
//
// Fix: every ~25 seconds, ping each open connection. If a connection
// didn't answer the *previous* ping, it's assumed dead and is forcibly
// terminated — which fires the normal 'close' handler below and cleans
// up the room exactly as if the browser had disconnected properly. Live
// connections respond to pings automatically (built into the 'ws'
// library / the browser's WebSocket implementation) with no visible
// effect on the app.
//
// To remove: delete this whole comment block, the "HEARTBEAT MODULE"
// lines inside wss.on('connection', ...), and the setInterval block near
// the bottom of the file.
// ===== HEARTBEAT MODULE END =================================================

const express = require('express');
const http = require('http');
const path = require('path');
const WebSocket = require('ws');

const app = express();
app.use(express.static(path.join(__dirname, 'public')));

// Simple health check — useful for confirming the server is alive after deploy.
app.get('/healthz', (req, res) => res.send('ok'));

const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// roomId -> Set<WebSocket>
const rooms = new Map();

function send(ws, msg) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(msg));
  }
}

wss.on('connection', (ws, req) => {
  let room = 'gym-session';
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    room = url.searchParams.get('room') || room;
  } catch (e) {
    // fall back to default room name
  }

  if (!rooms.has(room)) rooms.set(room, new Set());
  const peers = rooms.get(room);

  if (peers.size >= 2) {
    send(ws, { type: 'full' });
    ws.close();
    return;
  }

  peers.add(ws);
  ws.roomId = room;

  // HEARTBEAT MODULE: mark this connection alive, and refresh that mark
  // whenever a pong comes back (browsers answer pings automatically).
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });

  // Tell this client how many people (including itself) are now in the room.
  // 1 = first to arrive, waits. 2 = second to arrive, becomes the caller.
  send(ws, { type: 'joined', peers: peers.size });

  // Let anyone already in the room know someone new showed up.
  peers.forEach((peer) => {
    if (peer !== ws) send(peer, { type: 'peer-joined' });
  });

  ws.on('message', (data) => {
    let msg;
    try {
      msg = JSON.parse(data);
    } catch (e) {
      return; // ignore anything that isn't valid JSON
    }
    // Relay signaling messages (offer/answer/candidate) to the other peer only.
    peers.forEach((peer) => {
      if (peer !== ws) send(peer, msg);
    });
  });

  ws.on('close', () => {
    peers.delete(ws);
    peers.forEach((peer) => send(peer, { type: 'peer-left' }));
    if (peers.size === 0) rooms.delete(room);
  });

  ws.on('error', () => {
    peers.delete(ws);
  });
});

// ===== HEARTBEAT MODULE: periodic ping/dead-connection sweep =====
setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      // Didn't respond to the previous ping — treat as dead. terminate()
      // triggers the 'close' handler above, which cleans up the room the
      // same way a normal disconnect would.
      return ws.terminate();
    }
    ws.isAlive = false;
    ws.ping();
  });
}, 25000);
// ===== HEARTBEAT MODULE END =====

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Signaling server listening on port ${PORT}`);
});
