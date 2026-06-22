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

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Signaling server listening on port ${PORT}`);
});
