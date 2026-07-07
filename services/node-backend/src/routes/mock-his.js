const { Router } = require('express');

const router = Router();
const receivedBundles = [];

// Receive FHIR bundle
router.post('/fhir/bundle', (req, res) => {
  const bundle = req.body;
  receivedBundles.push({
    received_at: new Date().toISOString(),
    bundle,
  });
  console.log(`[mock-his] Received FHIR bundle. Total: ${receivedBundles.length}`);
  res.json({ status: 'accepted', id: receivedBundles.length });
});

// Dashboard data
router.get('/dashboard', (req, res) => {
  res.json(receivedBundles);
});

module.exports = router;
