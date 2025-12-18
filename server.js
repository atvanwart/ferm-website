'use strict';

/*
 PHASE 1 NOTE:
 - Adds SAFE /handshake/preview route
 - No Supabase writes
 - No Canvas calls
 - No side effects

 PHASE 2 NOTE:
 - Adds OTP email login (no passwords)
 - No profile writes
 - No role escalation
*/

// SECTION INDEX
// 1) BOOT + MIDDLEWARE
// 2) ADMIN AUTH
// 3) JSON HELPERS
// 4) CANVAS API
// 5) ADMIN ROUTES
// 6) AUTOPURGE
// 7) AI
// 8) SIGNUP
// 9) HANDSHAKE (PHASE 1b)
// 10) AUTH (PHASE II OTP)
// 11) LISTEN/BOOTSTRAP

// === SECTION: BOOT + MIDDLEWARE ===
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const crypto = require('crypto');

const { safeReadJson, safeWriteJson } = require('./src/jsonStore');
const { loadCourses, getCourse } = require('./src/courses');

const {
  canvasGetAll,
  protectedUserSet,
  fetchStudentEnrollments,
  splitEnrollments,
  purgeCourseEnrollments
} = require('./src/canvas');

const { createAutopurge } = require('./src/autopurge');

console.log('Starting Fermentors server…');

const app = express();
const port = process.env.PORT || 3000;

app.use(helmet());
app.use(express.json());
app.use(express.static('public'));

const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 30 });
const aiLimiter   = rateLimit({ windowMs: 15 * 60 * 1000, max: 60 });
// === ENDSECTION: BOOT + MIDDLEWARE ===


// === SECTION: ADMIN AUTH ===
function requireAdmin(req, res, next) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Basic ')) {
    res.set('WWW-Authenticate', 'Basic realm="Fermentors Admin"');
    return res.status(401).send('Admin authentication required.');
  }
  const decoded = Buffer.from(header.slice(6), 'base64').toString('utf8');
  const [user, pass] = decoded.split(':');
  if (user === process.env.ADMIN_USER && pass === process.env.ADMIN_PASS) return next();
  return res.status(403).send('Forbidden.');
}

function requireAiKey(req, res, next) {
  const provided = req.headers['x-fermentors-ai-key'];
  if (provided && provided === process.env.AI_SHARED_SECRET) return next();
  return res.status(401).json({ error: 'Missing/invalid AI key.' });
}
// === ENDSECTION: ADMIN AUTH ===


// === SECTION: JSON HELPERS ===
let personalities = {};
try {
  personalities = JSON.parse(fs.readFileSync(path.join(__dirname, 'personalities.json'), 'utf-8'));
} catch {
  personalities = {};
}

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY || 'missing'
);

function getBearerToken(req) {
  const h = req.headers.authorization || '';
  if (!h.toLowerCase().startsWith('bearer ')) return null;
  return h.slice(7).trim();
}
// === ENDSECTION: JSON HELPERS ===


// === SECTION: HANDSHAKE (PHASE 1b) ===
app.get('/handshake/preview', (req, res) => {
  res.json({
    ok: true,
    phase: 1,
    purpose: 'preview-only',
    message: 'Handshake endpoint alive (no side effects)',
    time: new Date().toISOString()
  });
});
// === ENDSECTION: HANDSHAKE ===


// === SECTION: AUTH (PHASE II OTP) ===

// POST /auth/start
// Body: { email }
app.post('/auth/start', authLimiter, async (req, res) => {
  const email = String((req.body || {}).email || '').trim();
  if (!email) return res.status(400).json({ ok: false, error: 'Missing email.' });

  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: true }
  });

  if (error) {
    return res.status(500).json({ ok: false, error: error.message });
  }

  return res.json({ ok: true });
});

// POST /auth/verify
// Body: { email, token }
app.post('/auth/verify', authLimiter, async (req, res) => {
  const { email, token } = req.body || {};
  if (!email || !token) {
    return res.status(400).json({ ok: false, error: 'Missing email or token.' });
  }

  const { data, error } = await supabase.auth.verifyOtp({
    email,
    token,
    type: 'email'
  });

  if (error || !data?.session) {
    return res.status(401).json({ ok: false, error: 'Invalid or expired code.' });
  }

  return res.json({ ok: true, session: data.session });
});

// GET /me
// Requires Authorization: Bearer <access_token>
app.get('/me', async (req, res) => {
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ ok: false, error: 'Missing token.' });

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) {
    return res.status(401).json({ ok: false, error: 'Invalid token.' });
  }

  return res.json({ ok: true, user: data.user });
});

// === ENDSECTION: AUTH ===


// === SECTION: LISTEN/BOOTSTRAP ===
app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
// === ENDSECTION: LISTEN/BOOTSTRAP ===
