warning: in the working copy of 'services/node-backend/src/routes/alerts.js', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/node-backend/src/routes/doctor.js', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/node-backend/src/routes/followup.js', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/node-backend/src/routes/prescription.js', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/node-backend/src/routes/protocol.js', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/node-backend/src/routes/questionnaire.js', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/node-backend/src/routes/vitals.js', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/python-backend/src/auth.py', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/python-backend/src/main.py', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/python-backend/src/routers/audio.py', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/python-backend/src/routers/llm.py', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/python-backend/src/routers/ocr.py', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/python-backend/src/routers/report.py', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/python-backend/src/routers/transcribe.py', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'services/python-backend/src/routers/triage.py', LF will be replaced by CRLF the next time Git touches it
[1mdiff --git a/services/node-backend/src/routes/alerts.js b/services/node-backend/src/routes/alerts.js[m
[1mindex d175f14..b669ff9 100644[m
[1m--- a/services/node-backend/src/routes/alerts.js[m
[1m+++ b/services/node-backend/src/routes/alerts.js[m
[36m@@ -1,12 +1,35 @@[m
 const { Router } = require('express');[m
[32m+[m[32mconst { verifyToken } = require('../middleware/auth');[m
 [m
 const router = Router();[m
 [m
 // Connected SSE clients[m
 const clients = new Set();[m
 [m
[31m-// SSE endpoint for nursing station alerts[m
[31m-router.get('/stream', (req, res) => {[m
[32m+[m[32m// SSE endpoint for nursing station alerts.[m
[32m+[m[32m//[m
[32m+[m[32m// The broadcast payload carries patient_name + department (see python triage.py),[m
[32m+[m[32m// so this must not be open. EventSource cannot set an Authorization header, so the[m
[32m+[m[32m// token is accepted from ?token= as well — the standard workaround. Restricted to[m
[32m+[m[32m// clinical staff; a patient token (mintable by anyone via /api/session/scan) is[m
[32m+[m[32m// not enough.[m
[32m+[m[32mfunction requireClinicalSse(req, res, next) {[m
[32m+[m[32m  const header = req.headers.authorization || '';[m
[32m+[m[32m  const raw = header.startsWith('Bearer ') ? header.slice(7) : (req.query.token || header);[m
[32m+[m[32m  if (!raw) return res.status(401).json({ error: 'No token provided' });[m
[32m+[m[32m  try {[m
[32m+[m[32m    const claims = verifyToken(raw);[m
[32m+[m[32m    if (claims.role !== 'doctor' && claims.role !== 'admin') {[m
[32m+[m[32m      return res.status(403).json({ error: 'Forbidden: insufficient role' });[m
[32m+[m[32m    }[m
[32m+[m[32m    req.session_data = claims;[m
[32m+[m[32m    next();[m
[32m+[m[32m  } catch {[m
[32m+[m[32m    return res.status(401).json({ error: 'Invalid token' });[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mrouter.get('/stream', requireClinicalSse, (req, res) => {[m
   res.writeHead(200, {[m
     'Content-Type': 'text/event-stream',[m
     'Cache-Control': 'no-cache',[m
[1mdiff --git a/services/node-backend/src/routes/doctor.js b/services/node-backend/src/routes/doctor.js[m
[1mindex c8f2920..276fbb2 100644[m
[1m--- a/services/node-backend/src/routes/doctor.js[m
[1m+++ b/services/node-backend/src/routes/doctor.js[m
[36m@@ -1,12 +1,19 @@[m
 const { Router } = require('express');[m
 const crypto = require('crypto');[m
 const pool = require('../models/db');[m
[31m-const { signToken, verifyToken, authMiddleware, requireRole } = require('../middleware/auth');[m
[32m+[m[32mconst { signToken, authMiddleware, requireRole } = require('../middleware/auth');[m
 [m
 const router = Router();[m
 [m
[32m+[m[32m// Every route below that acts as a doctor. Previously each handler re-implemented[m
[32m+[m[32m// this by hand (read the header, verifyToken, check role) — and three routes[m
[32m+[m[32m// forgot to, leaving them fully open. One shared gate, applied declaratively.[m
[32m+[m[32mconst doctorOnly = [authMiddleware, requireRole('doctor')];[m
[32m+[m[32m// Clinical staff: the HIS admin dashboard and the doctor console both reach these.[m
[32m+[m[32mconst clinicalOnly = [authMiddleware, requireRole('doctor', 'admin')];[m
[32m+[m
 function hashPin(pin) {[m
[31m-  return crypto.createHash('sha256').update(pin).digest('hex');[m
[32m+[m[32m  return crypto.createHash('sha256').update(String(pin)).digest('hex');[m
 }[m
 [m
 // Doctor PIN login[m
[36m@@ -55,7 +62,7 @@[m [mrouter.post('/', authMiddleware, requireRole('admin'), async (req, res) => {[m
     if (!name || !department || !phone || !pin) {[m
       return res.status(400).json({ error: 'name, department, phone, pin are required' });[m
     }[m
[31m-    if (pin.length < 4 || pin.length > 6 || !/^\d+$/.test(pin)) {[m
[32m+[m[32m    if (!/^\d{4,6}$/.test(String(pin))) {[m
       return res.status(400).json({ error: 'PIN must be 4-6 digits' });[m
     }[m
 [m
[36m@@ -101,7 +108,7 @@[m [mrouter.patch('/:id', authMiddleware, requireRole('admin'), async (req, res) => {[m
       params.push(String(phone).trim()); sets.push(`phone = $${params.length}`);[m
     }[m
     if (pin !== undefined && pin !== '') {[m
[31m-      if (pin.length < 4 || pin.length > 6 || !/^\d+$/.test(pin)) {[m
[32m+[m[32m      if (!/^\d{4,6}$/.test(String(pin))) {[m
         return res.status(400).json({ error: 'PIN must be 4-6 digits' });[m
       }[m
       params.push(hashPin(pin)); sets.push(`pin_hash = $${params.length}`);[m
[36m@@ -154,11 +161,18 @@[m [mrouter.post('/:id/reactivate', authMiddleware, requireRole('admin'), async (req,[m
   }[m
 });[m
 [m
[31m-// List doctors (for admin)[m
[31m-router.get('/', async (req, res) => {[m
[32m+[m[32m// List doctors. Any authenticated caller — the patient registration page offers a[m
[32m+[m[32m// "preferred doctor" chooser. A doctor's PHONE NUMBER is staff contact data, not[m
[32m+[m[32m// something a patient kiosk needs, so it is only returned to admins (the HIS[m
[32m+[m[32m// doctor-management screen is the only reader).[m
[32m+[m[32mrouter.get('/', authMiddleware, async (req, res) => {[m
   try {[m
     const { department } = req.query;[m
[31m-    let q = 'SELECT id, name, department, phone, registration_no, is_active, created_at FROM doctors WHERE 1=1';[m
[32m+[m[32m    const isAdmin = req.session_data.role === 'admin';[m
[32m+[m[32m    const cols = isAdmin[m
[32m+[m[32m      ? 'id, name, department, phone, registration_no, is_active, created_at'[m
[32m+[m[32m      : 'id, name, department, registration_no, is_active, created_at';[m
[32m+[m[32m    let q = `SELECT ${cols} FROM doctors WHERE 1=1`;[m
     const params = [];[m
     if (department) { params.push(department); q += ` AND department = $${params.length}`; }[m
     q += ' ORDER BY name';[m
[36m@@ -170,15 +184,9 @@[m [mrouter.get('/', async (req, res) => {[m
 });[m
 [m
 // Get doctor's queue — assigned to them + unassigned in their department[m
[31m-router.get('/queue', async (req, res) => {[m
[32m+[m[32mrouter.get('/queue', ...doctorOnly, async (req, res) => {[m
   try {[m
[31m-    const auth = req.headers.authorization;[m
[31m-    if (!auth) return res.status(401).json({ error: 'No token' });[m
[31m-[m
[31m-    const decoded = verifyToken(auth.replace('Bearer ', ''));[m
[31m-    if (decoded.role !== 'doctor') return res.status(403).json({ error: 'Not a doctor token' });[m
[31m-[m
[31m-    const { doctor_id, department } = decoded;[m
[32m+[m[32m    const { doctor_id, department } = req.session_data;[m
 [m
     // Patient directory: ALL completed visits in this department (full history,[m
     // not just the last 24h), so each patient's previous visits can be grouped[m
[36m@@ -229,24 +237,28 @@[m [mrouter.get('/queue', async (req, res) => {[m
   }[m
 });[m
 [m
[31m-// Assign session to doctor (self-assign or by admin)[m
[31m-router.post('/assign/:session_id', async (req, res) => {[m
[32m+[m[32m// Assign session to doctor (self-assign)[m
[32m+[m[32mrouter.post('/assign/:session_id', ...doctorOnly, async (req, res) => {[m
   try {[m
[31m-    const auth = req.headers.authorization;[m
[31m-    if (!auth) return res.status(401).json({ error: 'No token' });[m
[31m-[m
[31m-    const decoded = verifyToken(auth.replace('Bearer ', ''));[m
[31m-    if (decoded.role !== 'doctor') return res.status(403).json({ error: 'Not a doctor token' });[m
[32m+[m[32m    const decoded = req.session_data;[m
 [m
     // consulted_at is stamped ONCE (first open) and never overwritten, so the[m
     // Consulted list keeps a fixed order even when a patient is re-opened.[m
[32m+[m[32m    //[m
[32m+[m[32m    // The WHERE clause mirrors /open: acquire only if the visit is free or already[m
[32m+[m[32m    // mine, and not yet dispatched. Without it this route was an unconditional[m
[32m+[m[32m    // UPDATE — a second doctor could take a patient another doctor had locked,[m
[32m+[m[32m    // silently defeating the mutual exclusion /open implements.[m
     const result = await pool.query([m
       `UPDATE sessions SET assigned_doctor_id = $1, updated_at = NOW(),[m
               consulted_at = COALESCE(consulted_at, NOW())[m
[31m-       WHERE id = $2 RETURNING *`,[m
[32m+[m[32m       WHERE id = $2[m
[32m+[m[32m         AND dispatched_at IS NULL[m
[32m+[m[32m         AND (assigned_doctor_id IS NULL OR assigned_doctor_id = $1)[m
[32m+[m[32m       RETURNING *`,[m
       [decoded.doctor_id, req.params.session_id][m
     );[m
[31m-    if (!result.rows.length) return res.status(404).json({ error: 'Session not found' });[m
[32m+[m[32m    if (!result.rows.length) return await explainLockFailure(req, res);[m
 [m
     await pool.query([m
       `INSERT INTO audit_log (session_id, event_type, actor, payload) VALUES ($1, 'doctor_assigned', $2, $3)`,[m
[36m@@ -260,15 +272,30 @@[m [mrouter.post('/assign/:session_id', async (req, res) => {[m
   }[m
 });[m
 [m
[32m+[m[32m// A guarded lock UPDATE matched no row. Distinguish "no such session" (404) from[m
[32m+[m[32m// "held by another doctor / already dispatched" (409) so the UI can say which.[m
[32m+[m[32masync function explainLockFailure(req, res) {[m
[32m+[m[32m  const cur = await pool.query([m
[32m+[m[32m    `SELECT s.dispatched_at, d.name AS doctor_name[m
[32m+[m[32m       FROM sessions s LEFT JOIN doctors d ON s.assigned_doctor_id = d.id[m
[32m+[m[32m      WHERE s.id = $1`,[m
[32m+[m[32m    [req.params.session_id][m
[32m+[m[32m  );[m
[32m+[m[32m  if (!cur.rows.length) return res.status(404).json({ error: 'Session not found' });[m
[32m+[m[32m  const row = cur.rows[0];[m
[32m+[m[32m  return res.status(409).json({[m
[32m+[m[32m    error: 'locked',[m
[32m+[m[32m    locked_by: row.doctor_name || 'another doctor',[m
[32m+[m[32m    dispatched: !!row.dispatched_at,[m
[32m+[m[32m  });[m
[32m+[m[32m}[m
[32m+[m
 // OPEN (lock) a patient's visit for consultation. Atomic: succeeds only if the[m
 // visit is free or already mine and not yet dispatched. If another doctor holds[m
 // it, returns 409 with their name so the UI can say "being consulted already".[m
[31m-router.post('/open/:session_id', async (req, res) => {[m
[32m+[m[32mrouter.post('/open/:session_id', ...doctorOnly, async (req, res) => {[m
   try {[m
[31m-    const auth = req.headers.authorization;[m
[31m-    if (!auth) return res.status(401).json({ error: 'No token' });[m
[31m-    const decoded = verifyToken(auth.replace('Bearer ', ''));[m
[31m-    if (decoded.role !== 'doctor') return res.status(403).json({ error: 'Not a doctor token' });[m
[32m+[m[32m    const decoded = req.session_data;[m
 [m
     // One active consultation per doctor: block opening a new patient while another[m
     // is still open (consulted, not yet dispatched). A patient merely reassigned to[m
[36m@@ -330,23 +357,24 @@[m [mrouter.post('/open/:session_id', async (req, res) => {[m
 // DISPATCH — the consultation is complete (Save & Generate QR clicked). Stamps[m
 // dispatched_at, which removes the visit from the active queue and moves it into[m
 // the doctor's Consulted list, releasing the lock.[m
[31m-router.post('/dispatch/:session_id', async (req, res) => {[m
[32m+[m[32mrouter.post('/dispatch/:session_id', ...doctorOnly, async (req, res) => {[m
   try {[m
[31m-    const auth = req.headers.authorization;[m
[31m-    if (!auth) return res.status(401).json({ error: 'No token' });[m
[31m-    const decoded = verifyToken(auth.replace('Bearer ', ''));[m
[31m-    if (decoded.role !== 'doctor') return res.status(403).json({ error: 'Not a doctor token' });[m
[32m+[m[32m    const decoded = req.session_data;[m
 [m
[32m+[m[32m    // Only the doctor holding the visit (or nobody) may finish it — a doctor must[m
[32m+[m[32m    // not be able to close out a consultation another doctor is running.[m
     const result = await pool.query([m
       `UPDATE sessions[m
           SET dispatched_at = NOW(),[m
               assigned_doctor_id = COALESCE(assigned_doctor_id, $1),[m
               consulted_at = COALESCE(consulted_at, NOW()),[m
               updated_at = NOW()[m
[31m-        WHERE id = $2 RETURNING *`,[m
[32m+[m[32m        WHERE id = $2[m
[32m+[m[32m          AND (assigned_doctor_id IS NULL OR assigned_doctor_id = $1)[m
[32m+[m[32m        RETURNING *`,[m
       [decoded.doctor_id, req.params.session_id][m
     );[m
[31m-    if (!result.rows.length) return res.status(404).json({ error: 'Session not found' });[m
[32m+[m[32m    if (!result.rows.length) return await explainLockFailure(req, res);[m
 [m
     await pool.query([m
       `INSERT INTO audit_log (session_id, event_type, actor, payload) VALUES ($1, 'doctor_dispatched', $2, $3)`,[m
[36m@@ -360,21 +388,20 @@[m [mrouter.post('/dispatch/:session_id', async (req, res) => {[m
 });[m
 [m
 // Unassign session — send back to pool[m
[31m-router.post('/unassign/:session_id', async (req, res) => {[m
[32m+[m[32mrouter.post('/unassign/:session_id', ...doctorOnly, async (req, res) => {[m
   try {[m
[31m-    const auth = req.headers.authorization;[m
[31m-    if (!auth) return res.status(401).json({ error: 'No token' });[m
[31m-[m
[31m-    const decoded = verifyToken(auth.replace('Bearer ', ''));[m
[31m-    if (decoded.role !== 'doctor') return res.status(403).json({ error: 'Not a doctor token' });[m
[32m+[m[32m    const decoded = req.session_data;[m
 [m
     // Abandon a lock — release the patient back to "waiting" (clear the doctor[m
[31m-    // link AND the consulted stamp so it's open for anyone again).[m
[32m+[m[32m    // link AND the consulted stamp so it's open for anyone again). Only the[m
[32m+[m[32m    // holding doctor may abandon; you cannot drop someone else's lock.[m
     const result = await pool.query([m
[31m-      `UPDATE sessions SET assigned_doctor_id = NULL, consulted_at = NULL, updated_at = NOW() WHERE id = $1 RETURNING *`,[m
[31m-      [req.params.session_id][m
[32m+[m[32m      `UPDATE sessions SET assigned_doctor_id = NULL, consulted_at = NULL, updated_at = NOW()[m
[32m+[m[32m        WHERE id = $1 AND (assigned_doctor_id IS NULL OR assigned_doctor_id = $2)[m
[32m+[m[32m        RETURNING *`,[m
[32m+[m[32m      [req.params.session_id, decoded.doctor_id][m
     );[m
[31m-    if (!result.rows.length) return res.status(404).json({ error: 'Session not found' });[m
[32m+[m[32m    if (!result.rows.length) return await explainLockFailure(req, res);[m
 [m
     await pool.query([m
       `INSERT INTO audit_log (session_id, event_type, actor, payload) VALUES ($1, 'doctor_unassigned', $2, $3)`,[m
[36m@@ -393,22 +420,20 @@[m [mrouter.post('/unassign/:session_id', async (req, res) => {[m
 // leaves the doctor's Consulted list entirely — and stamps released_at, which[m
 // makes the queue treat it as "filled now" again (re-surfaces at the top with a[m
 // NEW badge, like a fresh patient fill) and counts it as "waiting".[m
[31m-router.post('/release/:session_id', async (req, res) => {[m
[32m+[m[32mrouter.post('/release/:session_id', ...doctorOnly, async (req, res) => {[m
   try {[m
[31m-    const auth = req.headers.authorization;[m
[31m-    if (!auth) return res.status(401).json({ error: 'No token' });[m
[31m-[m
[31m-    const decoded = verifyToken(auth.replace('Bearer ', ''));[m
[31m-    if (decoded.role !== 'doctor') return res.status(403).json({ error: 'Not a doctor token' });[m
[32m+[m[32m    const decoded = req.session_data;[m
 [m
[32m+[m[32m    // Only the doctor who holds (or consulted) the visit may release it back.[m
     const result = await pool.query([m
       `UPDATE sessions[m
           SET assigned_doctor_id = NULL, consulted_at = NULL, dispatched_at = NULL,[m
               released_at = NOW(), updated_at = NOW()[m
[31m-        WHERE id = $1 RETURNING *`,[m
[31m-      [req.params.session_id][m
[32m+[m[32m        WHERE id = $1 AND (assigned_doctor_id IS NULL OR assigned_doctor_id = $2)[m
[32m+[m[32m        RETURNING *`,[m
[32m+[m[32m      [req.params.session_id, decoded.doctor_id][m
     );[m
[31m-    if (!result.rows.length) return res.status(404).json({ error: 'Session not found' });[m
[32m+[m[32m    if (!result.rows.length) return await explainLockFailure(req, res);[m
 [m
     await pool.query([m
       `INSERT INTO audit_log (session_id, event_type, actor, payload) VALUES ($1, 'doctor_released', $2, $3)`,[m
[36m@@ -430,7 +455,9 @@[m [mrouter.post('/release/:session_id', async (req, res) => {[m
 //   {}  / null            → unassign (back to the current department's general pool).[m
 // In every assign/move case we clear the handoff stamps (consulted_at, dispatched_at)[m
 // so the receiving doctor sees a fresh entry. Triage is preserved.[m
[31m-router.post('/reassign/:session_id', async (req, res) => {[m
[32m+[m[32m// Reached by BOTH the HIS admin dashboard and the doctor console (handoff), so[m
[32m+[m[32m// this is clinical-staff, not doctor-only. It previously had no auth check at all.[m
[32m+[m[32mrouter.post('/reassign/:session_id', ...clinicalOnly, async (req, res) => {[m
   try {[m
     const { target_doctor_id, department } = req.body;[m
 [m
[36m@@ -508,13 +535,9 @@[m [mrouter.post('/reassign/:session_id', async (req, res) => {[m
 });[m
 [m
 // Doctor's consulted patients — completed sessions assigned to them[m
[31m-router.get('/consulted', async (req, res) => {[m
[32m+[m[32mrouter.get('/consulted', ...doctorOnly, async (req, res) => {[m
   try {[m
[31m-    const auth = req.headers.authorization;[m
[31m-    if (!auth) return res.status(401).json({ error: 'No token' });[m
[31m-[m
[31m-    const decoded = verifyToken(auth.replace('Bearer ', ''));[m
[31m-    if (decoded.role !== 'doctor') return res.status(403).json({ error: 'Not a doctor token' });[m
[32m+[m[32m    const decoded = req.session_data;[m
 [m
     // Consulted = visits I finished (Save & Generate QR → dispatched_at set).[m
     // Merely opening/locking a patient does NOT put them here.[m
[36m@@ -545,8 +568,8 @@[m [mrouter.get('/consulted', async (req, res) => {[m
   }[m
 });[m
 [m
[31m-// All sessions with doctor info — for HIS/admin dashboard[m
[31m-router.get('/all-sessions', async (req, res) => {[m
[32m+[m[32m// All sessions with doctor info — for HIS/admin dashboard. Bulk PHI: staff only.[m
[32m+[m[32mrouter.get('/all-sessions', ...clinicalOnly, async (req, res) => {[m
   try {[m
     const { department, doctor_id, state, triage } = req.query;[m
     // display_state — the SINGLE source of truth for the HIS "State" column AND[m
[36m@@ -587,18 +610,7 @@[m [mrouter.get('/all-sessions', async (req, res) => {[m
 // (not erased), so it drops out of the active Queue and the patient's[m
 // previous-logins, but all its data is retained and it STAYS in the doctor's[m
 // Consulted history if it was consulted. Guarded behind doctor auth.[m
[31m-router.delete('/session/:session_id', async (req, res) => {[m
[31m-  const auth = req.headers.authorization;[m
[31m-  if (!auth) return res.status(401).json({ error: 'No token' });[m
[31m-[m
[31m-  let decoded;[m
[31m-  try {[m
[31m-    decoded = verifyToken(auth.replace('Bearer ', ''));[m
[31m-  } catch {[m
[31m-    return res.status(401).json({ error: 'Invalid token' });[m
[31m-  }[m
[31m-  if (decoded.role !== 'doctor') return res.status(403).json({ error: 'Not a doctor token' });[m
[31m-[m
[32m+[m[32mrouter.delete('/session/:session_id', ...doctorOnly, async (req, res) => {[m
   const { session_id } = req.params;[m
   try {[m
     const result = await pool.query([m
[36m@@ -614,17 +626,15 @@[m [mrouter.delete('/session/:session_id', async (req, res) => {[m
 });[m
 [m
 // Change PIN[m
[31m-router.post('/change-pin', async (req, res) => {[m
[32m+[m[32mrouter.post('/change-pin', ...doctorOnly, async (req, res) => {[m
   try {[m
[31m-    const auth = req.headers.authorization;[m
[31m-    if (!auth) return res.status(401).json({ error: 'No token' });[m
[31m-[m
[31m-    const decoded = verifyToken(auth.replace('Bearer ', ''));[m
[31m-    if (decoded.role !== 'doctor') return res.status(403).json({ error: 'Not a doctor token' });[m
[32m+[m[32m    const decoded = req.session_data;[m
 [m
     const { old_pin, new_pin } = req.body;[m
     if (!old_pin || !new_pin) return res.status(400).json({ error: 'old_pin and new_pin required' });[m
[31m-    if (new_pin.length < 4 || new_pin.length > 6) return res.status(400).json({ error: 'PIN must be 4-6 digits' });[m
[32m+[m[32m    // Coerce before measuring: a JSON number ({"new_pin": 1234}) has no .length,[m
[32m+[m[32m    // so the bounds check silently passed and hashPin() then threw a 500.[m
[32m+[m[32m    if (!/^\d{4,6}$/.test(String(new_pin))) return res.status(400).json({ error: 'PIN must be 4-6 digits' });[m
 [m
     const doc = await pool.query('SELECT pin_hash FROM doctors WHERE id = $1', [decoded.doctor_id]);[m
     if (!doc.rows.length || doc.rows[0].pin_hash !== hashPin(old_pin)) {[m
[1mdiff --git a/services/node-backend/src/routes/followup.js b/services/node-backend/src/routes/followup.js[m
[1mindex 83c7b46..757a2d9 100644[m
[1m--- a/services/node-backend/src/routes/followup.js[m
[1m+++ b/services/node-backend/src/routes/followup.js[m
[36m@@ -1,11 +1,17 @@[m
 const { Router } = require('express');[m
 const pool = require('../models/db');[m
 const { sendServerError } = require('../utils/http');[m
[32m+[m[32mconst { authMiddleware, requireRole } = require('../middleware/auth');[m
 [m
 const router = Router();[m
 [m
[32m+[m[32m// Clinical staff only. POST in particular accepts an arbitrary phone number and[m
[32m+[m[32m// message body which the follow-up worker then dispatches through Twilio — while[m
[32m+[m[32m// unauthenticated it was an open SMS/WhatsApp relay billed to this deployment.[m
[32m+[m[32mconst clinicalOnly = [authMiddleware, requireRole('doctor', 'admin')];[m
[32m+[m
 // List follow-ups (optionally filter by status)[m
[31m-router.get('/', async (req, res) => {[m
[32m+[m[32mrouter.get('/', ...clinicalOnly, async (req, res) => {[m
   try {[m
     const { status, phone } = req.query;[m
     let sql = 'SELECT f.*, s.patient_name, s.department FROM scheduled_followups f JOIN sessions s ON f.session_id = s.id';[m
[36m@@ -27,7 +33,7 @@[m [mrouter.get('/', async (req, res) => {[m
 });[m
 [m
 // Schedule a follow-up manually[m
[31m-router.post('/', async (req, res) => {[m
[32m+[m[32mrouter.post('/', ...clinicalOnly, async (req, res) => {[m
   try {[m
     const { session_id, protocol_id, patient_phone, message, send_at, channel } = req.body;[m
     if (!session_id || !patient_phone || !message || !send_at) {[m
[36m@@ -45,7 +51,7 @@[m [mrouter.post('/', async (req, res) => {[m
 });[m
 [m
 // Record patient response to a follow-up[m
[31m-router.post('/:id/respond', async (req, res) => {[m
[32m+[m[32mrouter.post('/:id/respond', ...clinicalOnly, async (req, res) => {[m
   try {[m
     const { response } = req.body;[m
     const responseLower = (response || '').toLowerCase();[m
[1mdiff --git a/services/node-backend/src/routes/prescription.js b/services/node-backend/src/routes/prescription.js[m
[1mindex 4093258..0429825 100644[m
[1m--- a/services/node-backend/src/routes/prescription.js[m
[1m+++ b/services/node-backend/src/routes/prescription.js[m
[36m@@ -2,11 +2,17 @@[m [mconst { Router } = require('express');[m
 const crypto = require('crypto');[m
 const pool = require('../models/db');[m
 const { authMiddleware, requireRole } = require('../middleware/auth');[m
[32m+[m[32mconst { requireSessionAccess } = require('../middleware/ownership');[m
 const { sendServerError } = require('../utils/http');[m
 const { mergeRxTemplate } = require('../rxTemplate');[m
 [m
 const router = Router();[m
 [m
[32m+[m[32m// Allergy records drive `block`-severity interaction warnings at prescribing time,[m
[32m+[m[32m// so writing them is a clinical act — an unauthenticated write could deny care by[m
[32m+[m[32m// injecting a fabricated allergy against any phone number.[m
[32m+[m[32mconst clinicalOnly = [authMiddleware, requireRole('doctor', 'admin')];[m
[32m+[m
 // ── Hospital prescription template (branding/theme/toggles) ──[m
 // GET is public — the patient-facing digital prescription page renders with it.[m
 router.get('/template', async (req, res) => {[m
[36m@@ -144,7 +150,7 @@[m [mrouter.post('/', authMiddleware, requireRole('doctor'), async (req, res) => {[m
 });[m
 [m
 // Get prescriptions for a session[m
[31m-router.get('/session/:session_id', async (req, res) => {[m
[32m+[m[32mrouter.get('/session/:session_id', authMiddleware, requireSessionAccess(), async (req, res) => {[m
   try {[m
     const rxs = await pool.query([m
       'SELECT p.*, d.name as doctor_name FROM prescriptions p LEFT JOIN doctors d ON p.doctor_id = d.id WHERE p.session_id = $1 ORDER BY p.created_at DESC',[m
[36m@@ -186,7 +192,7 @@[m [mrouter.post('/verify-qr', async (req, res) => {[m
 });[m
 [m
 // Patient allergies — list for a phone[m
[31m-router.get('/allergies/:phone', async (req, res) => {[m
[32m+[m[32mrouter.get('/allergies/:phone', ...clinicalOnly, async (req, res) => {[m
   try {[m
     const result = await pool.query([m
       'SELECT * FROM patient_allergies WHERE patient_phone = $1 ORDER BY created_at',[m
[36m@@ -199,7 +205,7 @@[m [mrouter.get('/allergies/:phone', async (req, res) => {[m
 });[m
 [m
 // Add allergy[m
[31m-router.post('/allergies', async (req, res) => {[m
[32m+[m[32mrouter.post('/allergies', ...clinicalOnly, async (req, res) => {[m
   try {[m
     const { patient_phone, allergen, reaction_type, severity, source } = req.body;[m
     if (!patient_phone || !allergen) {[m
[1mdiff --git a/services/node-backend/src/routes/protocol.js b/services/node-backend/src/routes/protocol.js[m
[1mindex b1f86ef..4bc5de7 100644[m
[1m--- a/services/node-backend/src/routes/protocol.js[m
[1m+++ b/services/node-backend/src/routes/protocol.js[m
[36m@@ -2,6 +2,7 @@[m [mconst { Router } = require('express');[m
 const pool = require('../models/db');[m
 const { sendServerError } = require('../utils/http');[m
 const { authMiddleware, requireRole } = require('../middleware/auth');[m
[32m+[m[32mconst { requireSessionAccess } = require('../middleware/ownership');[m
 [m
 const router = Router();[m
 [m
[36m@@ -107,8 +108,8 @@[m [mrouter.delete('/:id', ...adminOnly, async (req, res) => {[m
   }[m
 });[m
 [m
[31m-// Evaluate which protocols apply to a session[m
[31m-router.get('/evaluate/:session_id', async (req, res) => {[m
[32m+[m[32m// Evaluate which protocols apply to a session — reads the session's answers (PHI).[m
[32m+[m[32mrouter.get('/evaluate/:session_id', authMiddleware, requireSessionAccess(), async (req, res) => {[m
   try {[m
     const sessionId = req.params.session_id;[m
 [m
[1mdiff --git a/services/node-backend/src/routes/questionnaire.js b/services/node-backend/src/routes/questionnaire.js[m
[1mindex 29a7789..03b1ee1 100644[m
[1m--- a/services/node-backend/src/routes/questionnaire.js[m
[1m+++ b/services/node-backend/src/routes/questionnaire.js[m
[36m@@ -1,6 +1,7 @@[m
 const { Router } = require('express');[m
 const pool = require('../models/db');[m
 const { authMiddleware } = require('../middleware/auth');[m
[32m+[m[32mconst { requireSessionAccess } = require('../middleware/ownership');[m
 [m
 const router = Router();[m
 [m
[36m@@ -85,7 +86,7 @@[m [masync function walkDag(session_id, department) {[m
 }[m
 [m
 // Get next question for a session[m
[31m-router.get('/next/:session_id', authMiddleware, async (req, res) => {[m
[32m+[m[32mrouter.get('/next/:session_id', authMiddleware, requireSessionAccess(), async (req, res) => {[m
   try {[m
     const { session_id } = req.params;[m
 [m
[36m@@ -136,7 +137,7 @@[m [mrouter.get('/next/:session_id', authMiddleware, async (req, res) => {[m
 // Get the ordered list of previously-answered questions along the DAG path[m
 // actually taken — used by the client to rebuild its "Go Back" history stack[m
 // on mount (e.g. after returning from the documents/vitals pages).[m
[31m-router.get('/history/:session_id', authMiddleware, async (req, res) => {[m
[32m+[m[32mrouter.get('/history/:session_id', authMiddleware, requireSessionAccess(), async (req, res) => {[m
   try {[m
     const { session_id } = req.params;[m
 [m
[36m@@ -231,7 +232,7 @@[m [mrouter.post('/rewind', authMiddleware, async (req, res) => {[m
 });[m
 [m
 // Get all answers for a session[m
[31m-router.get('/answers/:session_id', async (req, res) => {[m
[32m+[m[32mrouter.get('/answers/:session_id', authMiddleware, requireSessionAccess(), async (req, res) => {[m
   try {[m
     const result = await pool.query([m
       'SELECT * FROM session_answers WHERE session_id = $1 ORDER BY created_at',[m
[1mdiff --git a/services/node-backend/src/routes/session.js b/services/node-backend/src/routes/session.js[m
[1mindex 1c73e8b..472890c 100644[m
[1m--- a/services/node-backend/src/routes/session.js[m
[1m+++ b/services/node-backend/src/routes/session.js[m
[36m@@ -1,6 +1,7 @@[m
 const { Router } = require('express');[m
 const pool = require('../models/db');[m
[31m-const { signToken, authMiddleware } = require('../middleware/auth');[m
[32m+[m[32mconst { signToken, authMiddleware, requireRole } = require('../middleware/auth');[m
[32m+[m[32mconst { requireSessionAccess } = require('../middleware/ownership');[m
 const { normalizeIndianPhone } = require('../utils/phone');[m
 const { APP_TIMEZONE } = require('../utils/time');[m
 [m
[36m@@ -260,8 +261,8 @@[m [mrouter.post('/state', authMiddleware, async (req, res) => {[m
   }[m
 });[m
 [m
[31m-// Get session by ID[m
[31m-router.get('/:id', async (req, res) => {[m
[32m+[m[32m// Get session by ID — the patient's own session, or any session for clinical staff.[m
[32m+[m[32mrouter.get('/:id', authMiddleware, requireSessionAccess('id'), async (req, res) => {[m
   try {[m
     const result = await pool.query([m
       `SELECT s.*, COALESCE(d.collect_vitals, true) AS collect_vitals[m
[36m@@ -277,8 +278,8 @@[m [mrouter.get('/:id', async (req, res) => {[m
   }[m
 });[m
 [m
[31m-// List sessions (for doctor queue)[m
[31m-router.get('/', async (req, res) => {[m
[32m+[m[32m// List sessions (for doctor queue) — bulk PHI, clinical staff only.[m
[32m+[m[32mrouter.get('/', authMiddleware, requireRole('doctor', 'admin'), async (req, res) => {[m
   try {[m
     const { department, state } = req.query;[m
     let query = 'SELECT * FROM sessions WHERE 1=1';[m
[1mdiff --git a/services/node-backend/src/routes/vitals.js b/services/node-backend/src/routes/vitals.js[m
[1mindex 0b4c0e8..e986ca7 100644[m
[1m--- a/services/node-backend/src/routes/vitals.js[m
[1m+++ b/services/node-backend/src/routes/vitals.js[m
[36m@@ -1,11 +1,13 @@[m
 const { Router } = require('express');[m
 const pool = require('../models/db');[m
 const { authMiddleware } = require('../middleware/auth');[m
[32m+[m[32mconst { requireSessionAccess } = require('../middleware/ownership');[m
 [m
 const router = Router();[m
 [m
[31m-// Submit vitals[m
[31m-router.post('/:session_id', authMiddleware, async (req, res) => {[m
[32m+[m[32m// Submit vitals. The :session_id is authorized against the caller's token — a[m
[32m+[m[32m// patient may only write their own; a nurse/doctor may write any (late vitals).[m
[32m+[m[32mrouter.post('/:session_id', authMiddleware, requireSessionAccess(), async (req, res) => {[m
   try {[m
     const { session_id } = req.params;[m
     const { bp_systolic, bp_diastolic, bp_side, weight_kg, spo2_pct, heart_rate, temperature_c, source } = req.body;[m
[36m@@ -33,7 +35,7 @@[m [mrouter.post('/:session_id', authMiddleware, async (req, res) => {[m
 });[m
 [m
 // Get vitals for session[m
[31m-router.get('/:session_id', async (req, res) => {[m
[32m+[m[32mrouter.get('/:session_id', authMiddleware, requireSessionAccess(), async (req, res) => {[m
   try {[m
     const result = await pool.query([m
       'SELECT * FROM session_vitals WHERE session_id = $1 ORDER BY recorded_at DESC LIMIT 1',[m
[1mdiff --git a/services/python-backend/src/auth.py b/services/python-backend/src/auth.py[m
[1mindex e7882b0..99262b4 100644[m
[1m--- a/services/python-backend/src/auth.py[m
[1m+++ b/services/python-backend/src/auth.py[m
[36m@@ -16,7 +16,7 @@[m [mimport json[m
 import os[m
 import time[m
 [m
[31m-from fastapi import Header, HTTPException[m
[32m+[m[32mfrom fastapi import Depends, Header, HTTPException[m
 [m
 # Known placeholder / dev values are rejected so a misconfigured deploy can't run[m
 # on a guessable signing key (matches the node side's fail-closed posture).[m
[36m@@ -72,8 +72,50 @@[m [mdef _verify(token: str) -> dict:[m
 [m
 async def require_auth(authorization: str = Header(default="")) -> dict:[m
     """FastAPI dependency: 401 unless a valid Bearer JWT is present. Returns the[m
[31m-    decoded claims (role, session_id, doctor_id, ...)."""[m
[32m+[m[32m    decoded claims (role, session_id, doctor_id, ...).[m
[32m+[m
[32m+[m[32m    NOTE: this proves only that the token is validly signed and unexpired. It says[m
[32m+[m[32m    NOTHING about role or which session the caller may touch — and a patient token[m
[32m+[m[32m    is obtainable by anyone (POST /api/session/scan is public by design). Any route[m
[32m+[m[32m    that reads or writes a specific patient's data must additionally use[m
[32m+[m[32m    `require_role(...)` or `assert_session_access(...)` below.[m
[32m+[m[32m    """[m
     if not authorization:[m
         raise HTTPException(status_code=401, detail="No token provided")[m
     token = authorization[7:] if authorization[:7].lower() == "bearer " else authorization[m
     return _verify(token)[m
[32m+[m
[32m+[m
[32m+[m[32mCLINICAL_ROLES = frozenset({"doctor", "admin"})[m
[32m+[m
[32m+[m
[32m+[m[32mdef require_role(*roles: str):[m
[32m+[m[32m    """FastAPI dependency factory: 403 unless the token's role is one of `roles`.[m
[32m+[m
[32m+[m[32m    Mirrors node's `requireRole` in middleware/auth.js. Usable at the router level[m
[32m+[m[32m    (`include_router(..., dependencies=[Depends(require_role("doctor"))])`) or on a[m
[32m+[m[32m    single route.[m
[32m+[m[32m    """[m
[32m+[m[32m    allowed = frozenset(roles)[m
[32m+[m
[32m+[m[32m    async def _dep(claims: dict = Depends(require_auth)) -> dict:[m
[32m+[m[32m        if (claims or {}).get("role") not in allowed:[m
[32m+[m[32m            raise HTTPException(status_code=403, detail="Forbidden: insufficient role")[m
[32m+[m[32m        return claims[m
[32m+[m
[32m+[m[32m    return _dep[m
[32m+[m
[32m+[m
[32m+[m[32mdef assert_session_access(session_id: str, claims: dict) -> None:[m
[32m+[m[32m    """Authorize `claims` against a specific `session_id`. Raises 403 otherwise.[m
[32m+[m
[32m+[m[32m    Mirrors node's `requireSessionAccess` in middleware/ownership.js:[m
[32m+[m[32m      patient      -> only the session their own token was issued for[m
[32m+[m[32m      doctor/admin -> any session (clinical staff)[m
[32m+[m[32m    """[m
[32m+[m[32m    role = (claims or {}).get("role")[m
[32m+[m[32m    if role in CLINICAL_ROLES:[m
[32m+[m[32m        return[m
[32m+[m[32m    if role == "patient" and session_id and claims.get("session_id") == session_id:[m
[32m+[m[32m        return[m
[32m+[m[32m    raise HTTPException(status_code=403, detail="Forbidden: not your session")[m
[1mdiff --git a/services/python-backend/src/main.py b/services/python-backend/src/main.py[m
[1mindex eb6cdfb..1cbdebc 100644[m
[1m--- a/services/python-backend/src/main.py[m
[1m+++ b/services/python-backend/src/main.py[m
[36m@@ -7,7 +7,7 @@[m [mfrom fastapi.middleware.cors import CORSMiddleware[m
 [m
 from .routers import llm, triage, report, ocr, prescription, scribe, drugs, audio, transcribe, tts[m
 from .llm_client import LLMUnavailable[m
[31m-from .auth import require_auth[m
[32m+[m[32mfrom .auth import require_auth, require_role[m
 from . import drug_repo[m
 [m
 logger = logging.getLogger(__name__)[m
[36m@@ -48,14 +48,26 @@[m [masync def unhandled_exception_handler(request: Request, exc: Exception):[m
 #   audio      → /clip/{id} (<audio src>) stays open[m
 #   ocr        → /documents/image/{id} (<img src>) stays open[m
 #   transcribe → /health stays open[m
[32m+[m[32m#[m
[32m+[m[32m# IMPORTANT: `require_auth` alone only proves the token is signed — and any caller[m
[32m+[m[32m# can mint a patient token via the public POST /api/session/scan. So a bare[m
[32m+[m[32m# `_auth` gate is equivalent to "public" for anything patient-specific. Routers[m
[32m+[m[32m# whose only legitimate callers are clinical staff are role-gated here; routers a[m
[32m+[m[32m# patient legitimately calls (llm, triage, report, ocr, audio, transcribe) gate[m
[32m+[m[32m# per-session inside the handler via `assert_session_access`.[m
 _auth = [Depends(require_auth)][m
[32m+[m[32m_clinical = [Depends(require_role("doctor", "admin"))][m
 app.include_router(llm.router, dependencies=_auth)[m
 app.include_router(triage.router, dependencies=_auth)[m
 app.include_router(report.router, dependencies=_auth)[m
 app.include_router(ocr.router)[m
[31m-app.include_router(prescription.router, dependencies=_auth)[m
[31m-app.include_router(scribe.router, dependencies=_auth)[m
[31m-app.include_router(drugs.router, dependencies=_auth)[m
[32m+[m[32m# Drug-interaction checks are a prescribing-time action (doctor console only).[m
[32m+[m[32mapp.include_router(prescription.router, dependencies=_clinical)[m
[32m+[m[32m# Consultation transcript + SOAP notes — doctor console only.[m
[32m+[m[32mapp.include_router(scribe.router, dependencies=_clinical)[m
[32m+[m[32m# Formulary read (autocomplete) is doctor-facing; the /admin/* and /review-queue/*[m
[32m+[m[32m# writes are admin-only and gated per-route inside drugs.py.[m
[32m+[m[32mapp.include_router(drugs.router, dependencies=_clinical)[m
 app.include_router(audio.router)[m
 app.include_router(transcribe.router)[m
 app.include_router(tts.router, dependencies=_auth)[m
[1mdiff --git a/services/python-backend/src/routers/audio.py b/services/python-backend/src/routers/audio.py[m
[1mindex d42c799..1b57f6d 100644[m
[1m--- a/services/python-backend/src/routers/audio.py[m
[1m+++ b/services/python-backend/src/routers/audio.py[m
[36m@@ -19,7 +19,7 @@[m [mfrom fastapi.responses import StreamingResponse[m
 [m
 from ..db import query, execute[m
 from .. import storage[m
[31m-from ..auth import require_auth[m
[32m+[m[32mfrom ..auth import require_auth, assert_session_access[m
 [m
 router = APIRouter(prefix="/api/audio", tags=["audio"])[m
 [m
[36m@@ -27,14 +27,16 @@[m [mrouter = APIRouter(prefix="/api/audio", tags=["audio"])[m
 # NOTE on auth: /answer and /session/{id} require a valid JWT. /clip/{id} is left[m
 # open because it's consumed as an <audio src> (see api.answerAudioUrl), which[m
 # can't send an Authorization header; it only serves bytes for an opaque clip id.[m
[31m-@router.post("/answer", dependencies=[Depends(require_auth)])[m
[32m+[m[32m@router.post("/answer")[m
 async def upload_answer_audio([m
     file: UploadFile = File(...),[m
     session_id: str = Form(...),[m
     question_id: Optional[str] = Form(default=None),[m
     duration_ms: Optional[int] = Form(default=None),[m
     transcript: Optional[str] = Form(default=None),[m
[32m+[m[32m    claims: dict = Depends(require_auth),[m
 ):[m
[32m+[m[32m    assert_session_access(session_id, claims)[m
     contents = await file.read()[m
     if not contents:[m
         raise HTTPException(status_code=400, detail="Empty audio")[m
[36m@@ -55,8 +57,9 @@[m [masync def upload_answer_audio([m
     return {"id": str(rows[0]["id"]) if rows else None}[m
 [m
 [m
[31m-@router.get("/session/{session_id}", dependencies=[Depends(require_auth)])[m
[31m-async def list_session_audio(session_id: str):[m
[32m+[m[32m@router.get("/session/{session_id}")[m
[32m+[m[32masync def list_session_audio(session_id: str, claims: dict = Depends(require_auth)):[m
[32m+[m[32m    assert_session_access(session_id, claims)[m
     rows = query([m
         """SELECT id, question_id, mime, duration_ms, transcript, created_at[m
              FROM answer_audio[m
[1mdiff --git a/services/python-backend/src/routers/drugs.py b/services/python-backend/src/routers/drugs.py[m
[1mindex 0939916..90066aa 100644[m
[1m--- a/services/python-backend/src/routers/drugs.py[m
[1m+++ b/services/python-backend/src/routers/drugs.py[m
[36m@@ -7,14 +7,21 @@[m [mAll under /api/drugs, which nginx already routes to python-backend (no nginx cha[m
 """[m
 from typing import List, Optional[m
 [m
[31m-from fastapi import APIRouter[m
[32m+[m[32mfrom fastapi import APIRouter, Depends[m
 from pydantic import BaseModel[m
 [m
 from .. import drug_repo[m
[32m+[m[32mfrom ..auth import require_role[m
 from ..drug_data import SORTED_GENERICS[m
 [m
 router = APIRouter(prefix="/api/drugs", tags=["drugs"])[m
 [m
[32m+[m[32m# The router is already gated to doctor+admin in main.py (doctors need GET /api/drugs[m
[32m+[m[32m# for the prescribe-tab autocomplete). Everything that MUTATES the curated formulary[m
[32m+[m[32m# or triages AI findings is admin-only: a doctor — let alone a patient token — must[m
[32m+[m[32m# not be able to delete an interaction rule such as warfarin x aspirin.[m
[32m+[m[32madmin_only = [Depends(require_role("admin"))][m
[32m+[m
 [m
 @router.get("")[m
 def list_drug_names():[m
[36m@@ -63,17 +70,17 @@[m [mclass ApproveIn(BaseModel):[m
 [m
 # ── Admin: drugs ──────────────────────────────────────────────────────────────[m
 [m
[31m-@router.get("/admin/drugs")[m
[32m+[m[32m@router.get("/admin/drugs", dependencies=admin_only)[m
 def admin_list_drugs():[m
     return drug_repo.list_drugs()[m
 [m
 [m
[31m-@router.post("/admin/drugs")[m
[32m+[m[32m@router.post("/admin/drugs", dependencies=admin_only)[m
 def admin_upsert_drug(body: DrugIn):[m
     return drug_repo.upsert_drug(body.generic, body.classes, body.aliases)[m
 [m
 [m
[31m-@router.delete("/admin/drugs")[m
[32m+[m[32m@router.delete("/admin/drugs", dependencies=admin_only)[m
 def admin_delete_drug(generic: str):[m
     drug_repo.delete_drug(generic)[m
     return {"ok": True}[m
[36m@@ -81,17 +88,17 @@[m [mdef admin_delete_drug(generic: str):[m
 [m
 # ── Admin: specific interactions ──────────────────────────────────────────────[m
 [m
[31m-@router.get("/admin/interactions")[m
[32m+[m[32m@router.get("/admin/interactions", dependencies=admin_only)[m
 def admin_list_interactions():[m
     return drug_repo.list_interactions()[m
 [m
 [m
[31m-@router.post("/admin/interactions")[m
[32m+[m[32m@router.post("/admin/interactions", dependencies=admin_only)[m
 def admin_upsert_interaction(body: InteractionIn):[m
     return drug_repo.upsert_interaction(body.generic_a, body.generic_b, body.severity, body.description)[m
 [m
 [m
[31m-@router.delete("/admin/interactions/{row_id}")[m
[32m+[m[32m@router.delete("/admin/interactions/{row_id}", dependencies=admin_only)[m
 def admin_delete_interaction(row_id: str):[m
     drug_repo.delete_interaction(row_id)[m
     return {"ok": True}[m
[36m@@ -99,17 +106,17 @@[m [mdef admin_delete_interaction(row_id: str):[m
 [m
 # ── Admin: class interactions ─────────────────────────────────────────────────[m
 [m
[31m-@router.get("/admin/class-interactions")[m
[32m+[m[32m@router.get("/admin/class-interactions", dependencies=admin_only)[m
 def admin_list_class_interactions():[m
     return drug_repo.list_class_interactions()[m
 [m
 [m
[31m-@router.post("/admin/class-interactions")[m
[32m+[m[32m@router.post("/admin/class-interactions", dependencies=admin_only)[m
 def admin_upsert_class_interaction(body: ClassInteractionIn):[m
     return drug_repo.upsert_class_interaction(body.class_a, body.class_b, body.severity, body.description)[m
 [m
 [m
[31m-@router.delete("/admin/class-interactions/{row_id}")[m
[32m+[m[32m@router.delete("/admin/class-interactions/{row_id}", dependencies=admin_only)[m
 def admin_delete_class_interaction(row_id: str):[m
     drug_repo.delete_class_interaction(row_id)[m
     return {"ok": True}[m
[36m@@ -117,17 +124,17 @@[m [mdef admin_delete_class_interaction(row_id: str):[m
 [m
 # ── Admin: allergy map ────────────────────────────────────────────────────────[m
 [m
[31m-@router.get("/admin/allergy-map")[m
[32m+[m[32m@router.get("/admin/allergy-map", dependencies=admin_only)[m
 def admin_list_allergy_map():[m
     return drug_repo.list_allergy_map()[m
 [m
 [m
[31m-@router.post("/admin/allergy-map")[m
[32m+[m[32m@router.post("/admin/allergy-map", dependencies=admin_only)[m
 def admin_upsert_allergy_map(body: AllergyMapIn):[m
     return drug_repo.upsert_allergy_map(body.allergen, body.drug_class)[m
 [m
 [m
[31m-@router.delete("/admin/allergy-map/{row_id}")[m
[32m+[m[32m@router.delete("/admin/allergy-map/{row_id}", dependencies=admin_only)[m
 def admin_delete_allergy_map(row_id: str):[m
     drug_repo.delete_allergy_map(row_id)[m
     return {"ok": True}[m
[36m@@ -135,18 +142,18 @@[m [mdef admin_delete_allergy_map(row_id: str):[m
 [m
 # ── Review queue (AI findings → admin curation) ───────────────────────────────[m
 [m
[31m-@router.get("/review-queue")[m
[32m+[m[32m@router.get("/review-queue", dependencies=admin_only)[m
 def review_queue(status: str = "pending"):[m
     return drug_repo.list_queue(status)[m
 [m
 [m
[31m-@router.post("/review-queue/{row_id}/approve")[m
[32m+[m[32m@router.post("/review-queue/{row_id}/approve", dependencies=admin_only)[m
 def review_approve(row_id: str, body: ApproveIn):[m
     result = drug_repo.approve(row_id, body.severity, body.description)[m
     return {"ok": result is not None, "approved": result}[m
 [m
 [m
[31m-@router.post("/review-queue/{row_id}/dismiss")[m
[32m+[m[32m@router.post("/review-queue/{row_id}/dismiss", dependencies=admin_only)[m
 def review_dismiss(row_id: str):[m
     drug_repo.dismiss(row_id)[m
     return {"ok": True}[m
[1mdiff --git a/services/python-backend/src/routers/llm.py b/services/python-backend/src/routers/llm.py[m
[1mindex 3804caa..bb61c0a 100644[m
[1m--- a/services/python-backend/src/routers/llm.py[m
[1m+++ b/services/python-backend/src/routers/llm.py[m
[36m@@ -1,11 +1,12 @@[m
 import os[m
 import re[m
 from pathlib import Path[m
[31m-from fastapi import APIRouter, HTTPException[m
[32m+[m[32mfrom fastapi import APIRouter, Depends, HTTPException[m
 from pydantic import BaseModel[m
 from typing import Optional[m
 import anthropic[m
 [m
[32m+[m[32mfrom ..auth import require_auth, assert_session_access[m
 from ..db import query[m
 [m
 router = APIRouter(prefix="/api/llm", tags=["llm"])[m
[36m@@ -23,7 +24,10 @@[m [mclass InterviewResponse(BaseModel):[m
     triage_flag: Optional[dict] = None[m
 [m
 @router.post("/interview", response_model=InterviewResponse)[m
[31m-async def interview(req: InterviewRequest):[m
[32m+[m[32masync def interview(req: InterviewRequest, claims: dict = Depends(require_auth)):[m
[32m+[m[32m    # Reads the session's prior answers into the prompt context — scope it.[m
[32m+[m[32m    assert_session_access(req.session_id, claims)[m
[32m+[m
     from ..llm_client import has_llm, complete as llm_complete[m
 [m
     if not has_llm():[m
[1mdiff --git a/services/python-backend/src/routers/ocr.py b/services/python-backend/src/routers/ocr.py[m
[1mindex 2975fbd..9489465 100644[m
[1m--- a/services/python-backend/src/routers/ocr.py[m
[1m+++ b/services/python-backend/src/routers/ocr.py[m
[36m@@ -11,7 +11,7 @@[m [mimport pytesseract[m
 [m
 from ..db import execute, query[m
 from .. import storage[m
[31m-from ..auth import require_auth[m
[32m+[m[32mfrom ..auth import require_auth, assert_session_access[m
 from ..llm_client import complete_with_image, has_llm, has_vision[m
 from ..drug_data import normalize_drug_name, GENERIC_DRUGS, SORTED_GENERICS[m
 [m
[36m@@ -268,14 +268,18 @@[m [mdef extract_with_vision(image_bytes: bytes, mime_type: str, ocr_text: str, ocr_c[m
 [m
 # ── Routes ────────────────────────────────────────────────────────────────────[m
 [m
[31m-@router.post("/process", dependencies=[Depends(require_auth)])[m
[32m+[m[32m@router.post("/process")[m
 async def process_document([m
     file: UploadFile = File(...),[m
     session_id: Optional[str] = Form(default=None),[m
     lang: Optional[str] = Form(default="eng"),[m
     doc_label: Optional[str] = Form(default=None),[m
[32m+[m[32m    claims: dict = Depends(require_auth),[m
 ):[m
     """Process an uploaded document image or PDF with AI vision + Tesseract fallback."""[m
[32m+[m[32m    # A document is attached to a session — only its owner (or clinical staff) may.[m
[32m+[m[32m    if session_id:[m
[32m+[m[32m        assert_session_access(session_id, claims)[m
     contents = await file.read()[m
 [m
     # Guard: reject oversized uploads before loading them into memory.[m
[36m@@ -407,17 +411,25 @@[m [masync def process_document([m
     }[m
 [m
 [m
[31m-@router.post("/confirm/{doc_id}", dependencies=[Depends(require_auth)])[m
[31m-async def confirm_document(doc_id: str, body: dict = {}):[m
[32m+[m[32m@router.post("/confirm/{doc_id}")[m
[32m+[m[32masync def confirm_document(doc_id: str, body: dict = {}, claims: dict = Depends(require_auth)):[m
     """Patient confirms or rejects OCR output."""[m
[32m+[m[32m    # Resolve the document's owning session before authorizing the write, so a[m
[32m+[m[32m    # patient can only confirm documents attached to their own session.[m
[32m+[m[32m    rows = query("SELECT session_id FROM session_documents WHERE id = %s", (doc_id,))[m
[32m+[m[32m    if not rows:[m
[32m+[m[32m        raise HTTPException(status_code=404, detail="Document not found")[m
[32m+[m[32m    assert_session_access(str(rows[0]["session_id"]), claims)[m
[32m+[m
     confirmed = body.get('confirmed', True)[m
     execute("UPDATE session_documents SET patient_confirmed = %s WHERE id = %s", (confirmed, doc_id))[m
     return {'confirmed': confirmed}[m
 [m
 [m
[31m-@router.get("/documents/{session_id}", dependencies=[Depends(require_auth)])[m
[31m-async def get_documents(session_id: str):[m
[32m+[m[32m@router.get("/documents/{session_id}")[m
[32m+[m[32masync def get_documents(session_id: str, claims: dict = Depends(require_auth)):[m
     """Get all documents for a session."""[m
[32m+[m[32m    assert_session_access(session_id, claims)[m
     return query([m
         "SELECT * FROM session_documents WHERE session_id = %s ORDER BY created_at",[m
         (session_id,),[m
[1mdiff --git a/services/python-backend/src/routers/ocr_stub.py b/services/python-backend/src/routers/ocr_stub.py[m
[1mdeleted file mode 100644[m
[1mindex c2f8802..0000000[m
[1m--- a/services/python-backend/src/routers/ocr_stub.py[m
[1m+++ /dev/null[m
[36m@@ -1,19 +0,0 @@[m
[31m-from fastapi import APIRouter, UploadFile, File[m
[31m-[m
[31m-router = APIRouter(prefix="/api/ocr", tags=["ocr"])[m
[31m-[m
[31m-@router.post("/process")[m
[31m-async def process_document(file: UploadFile = File(...)):[m
[31m-    # TODO: Implement real OCR with Tesseract / Google Doc AI[m
[31m-    return {[m
[31m-        "raw_text": "Sample prescription: Warfarin 5mg OD, Metoprolol 25mg BD, Enalapril 5mg OD",[m
[31m-        "structured": {[m
[31m-            "medications": [[m
[31m-                {"name": "Warfarin", "dose": "5mg", "frequency": "OD"},[m
[31m-                {"name": "Metoprolol", "dose": "25mg", "frequency": "BD"},[m
[31m-                {"name": "Enalapril", "dose": "5mg", "frequency": "OD"},[m
[31m-            ],[m
[31m-            "doc_type": "prescription",[m
[31m-        },[m
[31m-        "confidence": 0.85,[m
[31m-    }[m
[1mdiff --git a/services/python-backend/src/routers/report.py b/services/python-backend/src/routers/report.py[m
[1mindex 9d21246..c84ab7d 100644[m
[1m--- a/services/python-backend/src/routers/report.py[m
[1m+++ b/services/python-backend/src/routers/report.py[m
[36m@@ -11,18 +11,25 @@[m [mfrom typing import Optional[m
 import anthropic[m
 [m
 from ..db import query, execute[m
[31m-from ..auth import require_auth[m
[32m+[m[32mfrom ..auth import require_auth, require_role, assert_session_access[m
 from ..view_audit import record_view[m
 [m
 router = APIRouter(prefix="/api/report", tags=["report"])[m
 [m
[32m+[m[32m# Reading/editing a finished report is a clinician action (doctor console + HIS).[m
[32m+[m[32m# Patients never fetch a report — they only trigger /generate for their own session.[m
[32m+[m[32mclinical_only = [Depends(require_role("doctor", "admin"))][m
[32m+[m
 PROMPT_DIR = Path(__file__).parent.parent / "prompts"[m
 [m
 class ReportRequest(BaseModel):[m
     session_id: str[m
 [m
 @router.post("/generate")[m
[31m-async def generate_report(req: ReportRequest):[m
[32m+[m[32masync def generate_report(req: ReportRequest, claims: dict = Depends(require_auth)):[m
[32m+[m[32m    # Generating flips the session to COMPLETE (see _generate_report_impl), so an[m
[32m+[m[32m    # unscoped session_id let any caller force any patient's session into the queue.[m
[32m+[m[32m    assert_session_access(req.session_id, claims)[m
     try:[m
         return await _generate_report_impl(req)[m
     except HTTPException:[m
[36m@@ -154,7 +161,7 @@[m [masync def _generate_report_impl(req: ReportRequest):[m
     }[m
 [m
 [m
[31m-@router.get("/{session_id}")[m
[32m+[m[32m@router.get("/{session_id}", dependencies=clinical_only)[m
 async def get_report(session_id: str, claims: dict = Depends(require_auth)):[m
     reports = query([m
         "SELECT * FROM session_reports WHERE session_id = %s ORDER BY created_at DESC LIMIT 1",[m
[36m@@ -177,7 +184,7 @@[m [masync def get_report(session_id: str, claims: dict = Depends(require_auth)):[m
     }[m
 [m
 [m
[31m-@router.post("/{session_id}/feedback")[m
[32m+[m[32m@router.post("/{session_id}/feedback", dependencies=clinical_only)[m
 async def submit_feedback(session_id: str, feedback: dict):[m
     val = feedback.get("feedback")[m
     if val not in ("accurate", "inaccurate"):[m
[36m@@ -189,7 +196,7 @@[m [masync def submit_feedback(session_id: str, feedback: dict):[m
     return {"stored": True}[m
 [m
 [m
[31m-@router.post("/{session_id}/edit")[m
[32m+[m[32m@router.post("/{session_id}/edit", dependencies=clinical_only)[m
 async def edit_report(session_id: str, body: dict):[m
     """Store the doctor's full edited report markdown for the latest report. The AI[m
     original (report_md) is preserved untouched; the edited body lives in[m
[1mdiff --git a/services/python-backend/src/routers/transcribe.py b/services/python-backend/src/routers/transcribe.py[m
[1mindex 8714bd1..6153dcf 100644[m
[1m--- a/services/python-backend/src/routers/transcribe.py[m
[1m+++ b/services/python-backend/src/routers/transcribe.py[m
[36m@@ -18,7 +18,7 @@[m [mfrom fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends[m
 [m
 from ..db import execute[m
 from .. import storage[m
[31m-from ..auth import require_auth[m
[32m+[m[32mfrom ..auth import require_auth, assert_session_access[m
 from ..bhashini import asr, medcorrect, _llm[m
 [m
 router = APIRouter(prefix="/api/transcribe", tags=["transcribe"])[m
[36m@@ -47,7 +47,7 @@[m [masync def translate(text: str = Form(...), source_lang: str = Form(...)):[m
         raise HTTPException(status_code=502, detail="Translation unavailable")[m
 [m
 [m
[31m-@router.post("", dependencies=[Depends(require_auth)])[m
[32m+[m[32m@router.post("")[m
 async def transcribe([m
     file: UploadFile = File(...),[m
     lang: str = Form(...),                 # REQUIRED — never default to a language[m
[36m@@ -55,7 +55,11 @@[m [masync def transcribe([m
     session_id: Optional[str] = Form(default=None),[m
     question_id: Optional[str] = Form(default=None),[m
     duration_ms: Optional[int] = Form(default=None),[m
[32m+[m[32m    claims: dict = Depends(require_auth),[m
 ):[m
[32m+[m[32m    # The clip is persisted against session_id below — authorize that binding.[m
[32m+[m[32m    if session_id:[m
[32m+[m[32m        assert_session_access(session_id, claims)[m
     contents = await file.read()[m
     if not contents:[m
         raise HTTPException(status_code=400, detail="Empty audio")[m
[1mdiff --git a/services/python-backend/src/routers/triage.py b/services/python-backend/src/routers/triage.py[m
[1mindex dd47909..c37a03c 100644[m
[1m--- a/services/python-backend/src/routers/triage.py[m
[1m+++ b/services/python-backend/src/routers/triage.py[m
[36m@@ -1,8 +1,9 @@[m
 import os[m
 import json[m
[31m-from fastapi import APIRouter, HTTPException[m
[32m+[m[32mfrom fastapi import APIRouter, Depends, HTTPException[m
 from pydantic import BaseModel[m
 from typing import Optional[m
[32m+[m[32mfrom ..auth import require_auth, assert_session_access[m
 from ..db import query, execute[m
 [m
 router = APIRouter(prefix="/api/triage", tags=["triage"])[m
[36m@@ -41,7 +42,11 @@[m [mclass TriageResponse(BaseModel):[m
     triggered_rules: list[m
 [m
 @router.post("/evaluate", response_model=TriageResponse)[m
[31m-async def evaluate(req: TriageRequest):[m
[32m+[m[32masync def evaluate(req: TriageRequest, claims: dict = Depends(require_auth)):[m
[32m+[m[32m    # Writes triage_level onto the session and can fire a RED nursing alert —[m
[32m+[m[32m    # scope it to the caller's own session unless they are clinical staff.[m
[32m+[m[32m    assert_session_access(req.session_id, claims)[m
[32m+[m
     # Load answers[m
     answers_rows = query([m
         "SELECT question_id, answer_raw FROM session_answers WHERE session_id = %s",[m
