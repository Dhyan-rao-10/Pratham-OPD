// Authorization is the highest-risk logic in the app: get requireSessionAccess
// wrong and any valid token reads every patient's record. These tests pin the
// decision table so a future refactor can't silently open it up.
const { test } = require('node:test');
const assert = require('node:assert');
const { requireSessionAccess } = require('../src/middleware/ownership');

function mockRes() {
  return {
    statusCode: 200,
    body: null,
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
  };
}

// requireSessionAccess middleware is synchronous — next() fires (or doesn't)
// before this returns.
function run(mw, req) {
  const res = mockRes();
  let nexted = false;
  mw(req, res, () => { nexted = true; });
  return { res, nexted };
}

test('patient may access their own session', () => {
  const mw = requireSessionAccess();
  const { nexted } = run(mw, { session_data: { role: 'patient', session_id: 'S1' }, params: { session_id: 'S1' } });
  assert.equal(nexted, true);
});

test('patient is denied another patient session (403)', () => {
  const mw = requireSessionAccess();
  const { res, nexted } = run(mw, { session_data: { role: 'patient', session_id: 'S1' }, params: { session_id: 'S2' } });
  assert.equal(nexted, false);
  assert.equal(res.statusCode, 403);
});

test('doctor may access any session', () => {
  const mw = requireSessionAccess();
  const { nexted } = run(mw, { session_data: { role: 'doctor', session_id: 'SX' }, params: { session_id: 'S9' } });
  assert.equal(nexted, true);
});

test('admin may access any session', () => {
  const mw = requireSessionAccess();
  const { nexted } = run(mw, { session_data: { role: 'admin' }, params: { session_id: 'S9' } });
  assert.equal(nexted, true);
});

test('no token → 401', () => {
  const mw = requireSessionAccess();
  const { res, nexted } = run(mw, { params: { session_id: 'S1' } });
  assert.equal(nexted, false);
  assert.equal(res.statusCode, 401);
});

test('unknown role → 403', () => {
  const mw = requireSessionAccess();
  const { res, nexted } = run(mw, { session_data: { role: 'nurse' }, params: { session_id: 'S1' } });
  assert.equal(nexted, false);
  assert.equal(res.statusCode, 403);
});

test('custom param name is honoured', () => {
  const mw = requireSessionAccess('id');
  const { nexted } = run(mw, { session_data: { role: 'patient', session_id: 'S1' }, params: { id: 'S1' } });
  assert.equal(nexted, true);
});
