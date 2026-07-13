const { Router } = require('express');
const { verifyToken } = require('../middleware/auth');

const router = Router();

// Connected SSE clients
const clients = new Set();

// SSE endpoint for nursing station alerts.
//
// The broadcast payload carries patient_name + department (see python triage.py),
// so this must not be open. EventSource cannot set an Authorization header, so the
// token is accepted from ?token= as well — the standard workaround. Restricted to
// clinical staff; a patient token (mintable by anyone via /api/session/scan) is
// not enough.
function requireClinicalSse(req, res, next) {
  const header = req.headers.authorization || '';
  const raw = header.startsWith('Bearer ') ? header.slice(7) : (req.query.token || header);
  if (!raw) return res.status(401).json({ error: 'No token provided' });
  try {
    const claims = verifyToken(raw);
    if (claims.role !== 'doctor' && claims.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden: insufficient role' });
    }
    req.session_data = claims;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

router.get('/stream', requireClinicalSse, (req, res) => {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
  });
  res.write('data: {"type":"connected"}\n\n');

  clients.add(res);
  req.on('close', () => clients.delete(res));
});

// Broadcast alert to all connected SSE clients
function broadcast(data) {
  const msg = `data: ${JSON.stringify(data)}\n\n`;
  for (const client of clients) {
    client.write(msg);
  }
}

// Subscribe to Redis triage_alerts channel if available
function subscribeRedis() {
  const redisUrl = process.env.REDIS_URL;
  if (!redisUrl) return;

  try {
    const Redis = require('ioredis');
    const sub = new Redis(redisUrl);
    sub.subscribe('triage_alerts', (err) => {
      if (err) console.error('[alerts] Redis subscribe error:', err);
      else console.log('[alerts] Subscribed to triage_alerts channel');
    });
    sub.on('message', (channel, message) => {
      if (channel === 'triage_alerts') {
        try {
          const alert = JSON.parse(message);
          broadcast({ type: 'triage_alert', ...alert });
        } catch {}
      }
    });
  } catch (err) {
    console.log('[alerts] Redis not available for SSE alerts:', err.message);
  }
}

// Start Redis subscription on module load
subscribeRedis();

module.exports = router;
