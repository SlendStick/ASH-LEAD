#!/usr/bin/env node
/**
 * ASH&LEAD -- minimal WebSocket relay for browser multiplayer.
 *
 * Godot's WebSocketMultiplayerPeer in client mode needs a server that speaks
 * the raw WebSocket protocol and forwards binary frames verbatim. This relay
 * does exactly two things: it groups peers by room code, and it broadcasts
 * every packet it receives to every other peer in the same room. Godot's
 * high-level MultiplayerAPI handles peer ids, RPCs and ordering on top.
 *
 * Run:      node tools/relay_server.js [port] [--host 0.0.0.0]
 * Default:  0.0.0.0:9080
 * Connect:  ws://<host>:9080/<ROOM-CODE>
 *
 * No dependencies: implements RFC 6455 framing (text + binary, no extensions).
 */

const http = require('http');
const crypto = require('crypto');

const PORT = parseInt(process.argv[2] || '9080', 10);
const HOST = (() => {
  const i = process.argv.indexOf('--host');
  return i >= 0 ? process.argv[i + 1] : '0.0.0.0';
})();

const rooms = new Map(); // code -> Set<socket>

function secAccept(key) {
  return crypto
    .createHash('sha1')
    .update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
    .digest('base64');
}

function encodeFrame(payload, opcode = 0x2) {
  const len = payload.length;
  let header;
  if (len < 126) {
    header = Buffer.alloc(2);
    header[1] = len;
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[1] = 126;
    header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[1] = 127;
    header.writeBigUInt64BE(BigInt(len), 2);
  }
  header[0] = 0x80 | opcode;
  return Buffer.concat([header, payload]);
}

function extractFrames(buf, onMessage, onClose) {
  let offset = 0;
  while (offset + 2 <= buf.length) {
    const b0 = buf[offset];
    const b1 = buf[offset + 1];
    const opcode = b0 & 0x0f;
    const masked = (b1 & 0x80) !== 0;
    let len = b1 & 0x7f;
    let p = offset + 2;
    if (len === 126) {
      if (p + 2 > buf.length) break;
      len = buf.readUInt16BE(p);
      p += 2;
    } else if (len === 127) {
      if (p + 8 > buf.length) break;
      len = Number(buf.readBigUInt64BE(p));
      p += 8;
    }
    let mask = null;
    if (masked) {
      if (p + 4 > buf.length) break;
      mask = buf.subarray(p, p + 4);
      p += 4;
    }
    if (p + len > buf.length) break;
    let payload = Buffer.from(buf.subarray(p, p + len));
    if (masked) {
      for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i % 4];
    }
    offset = p + len;
    if (opcode === 0x8) {
      onClose();
      return { rest: Buffer.alloc(0), closed: true };
    } else if (opcode === 0x9) {
      onMessage(payload, 0xA);
    } else if (opcode === 0x1 || opcode === 0x2) {
      onMessage(payload, 0x2);
    }
  }
  return { rest: buf.subarray(offset), closed: false };
}

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' });
  res.end(
    `ASH&LEAD relay\nrooms: ${rooms.size}\npeers: ${[...rooms.values()].reduce((a, s) => a + s.size, 0)}\n` +
      `connect: ws://<host>:${PORT}/<ROOM-CODE>\n`
  );
});

server.on('upgrade', (req, socket) => {
  const key = req.headers['sec-websocket-key'];
  if (!key) {
    socket.destroy();
    return;
  }
  const room = (req.url || '/default').replace(/^\/+/, '').split('?')[0] || 'default';
  const accept = secAccept(key);
  socket.write(
    'HTTP/1.1 101 Switching Protocols\r\n' +
      'Upgrade: websocket\r\n' +
      'Connection: Upgrade\r\n' +
      `Sec-WebSocket-Accept: ${accept}\r\n\r\n`
  );
  socket.setNoDelay(true);
  if (!rooms.has(room)) rooms.set(room, new Set());
  rooms.get(room).add(socket);
  console.log(`[+] ${room} (${rooms.get(room).size} peers)`);

  const send = (payload, opcode = 0x2) => {
    try {
      socket.write(encodeFrame(payload, opcode));
    } catch (e) {
      /* peer vanished */
    }
  };

  const leave = () => {
    const set = rooms.get(room);
    if (set) {
      set.delete(socket);
      if (set.size === 0) rooms.delete(room);
    }
    console.log(`[-] ${room} (${rooms.has(room) ? rooms.get(room).size : 0} peers)`);
  };

  let buffer = Buffer.alloc(0);
  socket.on('data', (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    const result = extractFrames(
      buffer,
      (payload, opcode) => {
        if (opcode === 0xA) {
          send(payload, 0xA);
          return;
        }
        const set = rooms.get(room);
        if (!set) return;
        for (const peer of set) {
          if (peer === socket) continue;
          try {
            peer.write(encodeFrame(payload, 0x2));
          } catch (e) {
            /* ignore dead peer */
          }
        }
      },
      () => {
        leave();
        socket.end();
      }
    );
    buffer = result.rest;
    if (result.closed) leave();
  });
  socket.on('close', leave);
  socket.on('error', leave);
});

server.listen(PORT, HOST, () => {
  console.log(`ASH&LEAD relay listening on ws://${HOST}:${PORT}/<ROOM-CODE>`);
});
