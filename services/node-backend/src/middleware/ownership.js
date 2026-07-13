// Session-scoped authorization. Use AFTER authMiddleware.
//
// Signing a token is not the same as being allowed to read the session named in
// the URL. Every route that takes a :session_id must decide whose session that
// is allowed to be — otherwise any valid token (including one minted by the
// public POST /api/session/scan) reads every patient's record.
//
//   patient      -> may only touch the session their own token was issued for
//   doctor/admin -> clinical staff, may touch any session
//   anything else-> denied
//
// NOTE: doctors are deliberately NOT scoped to their own department here. The
// queue intentionally surfaces a patient's visits from other departments (see
// routes/doctor.js /queue) and reassignment moves patients across departments,
// so a department filter would break history. Narrowing clinical access further
// is a policy decision, not a code one.
const CLINICAL_ROLES = new Set(['doctor', 'admin']);

function requireSessionAccess(param = 'session_id') {
  return (req, res, next) => {
    const sd = req.session_data;
    if (!sd) return res.status(401).json({ error: 'No token provided' });

    if (CLINICAL_ROLES.has(sd.role)) return next();

    if (sd.role === 'patient') {
      const target = req.params[param];
      if (target && sd.session_id === target) return next();
      return res.status(403).json({ error: 'Forbidden: not your session' });
    }

    return res.status(403).json({ error: 'Forbidden: insufficient role' });
  };
}

module.exports = { requireSessionAccess };
