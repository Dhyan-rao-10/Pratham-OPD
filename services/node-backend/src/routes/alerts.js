const { Router } = require('express');

const router = Router();

// Connected SSE clients
const clients = new Set();

// SSE endpoint for nursing station alerts
router.get('/stream', (req, res) => {
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
