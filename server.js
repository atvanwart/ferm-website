'use strict';

// SECTION INDEX
// 1) BOOT + MIDDLEWARE
// 2) ADMIN AUTH
// 3) JSON HELPERS
// 4) CANVAS API
// 5) ADMIN ROUTES
// 6) AUTOPURGE
// 7) AI
// 8) SIGNUP
// 9) LISTEN/BOOTSTRAP

// === SECTION: BOOT + MIDDLEWARE ===
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

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

// ---- Startup sanity (no secrets printed) ----
console.log('Starting Fermentors server…');
console.log('ADMIN_USER loaded as:', process.env.ADMIN_USER || '(missing)');
console.log('ADMIN_PASS length:', (process.env.ADMIN_PASS || '').length);
console.log('AI_SHARED_SECRET set:', !!process.env.AI_SHARED_SECRET);
console.log('CANVAS_BASE_URL set:', !!process.env.CANVAS_BASE_URL);
console.log('CANVAS_TOKEN set:', !!process.env.CANVAS_TOKEN);

const app = express();
const port = process.env.PORT || 3000;

app.use(helmet());
app.use(express.json());
app.use(express.static('public'));

// ---- Rate limits (tune later) ----
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

  const base64 = header.slice('Basic '.length);
  const decoded = Buffer.from(base64, 'base64').toString('utf8');
  const idx = decoded.indexOf(':');
  const user = idx >= 0 ? decoded.slice(0, idx) : '';
  const pass = idx >= 0 ? decoded.slice(idx + 1) : '';

  if (user === process.env.ADMIN_USER && pass === process.env.ADMIN_PASS) return next();
  return res.status(403).send('Forbidden.');
}

function requireAiKey(req, res, next) {
  if (!process.env.AI_SHARED_SECRET) {
    return res.status(500).json({ error: 'Server misconfigured: missing AI_SHARED_SECRET' });
  }
  const provided = req.headers['x-fermentors-ai-key'];
  if (provided && provided === process.env.AI_SHARED_SECRET) return next();
  return res.status(401).json({ error: 'Missing/invalid AI key.' });
}
// === ENDSECTION: ADMIN AUTH ===


// === SECTION: JSON HELPERS ===
let personalities = {};
try {
  personalities = JSON.parse(fs.readFileSync(path.join(__dirname, 'personalities.json'), 'utf-8'));
} catch (e) {
  console.warn('Warning: personalities.json not loaded:', e.message);
  personalities = {};
}

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
// === ENDSECTION: JSON HELPERS ===


// === SECTION: CANVAS API ===
// NOTE: Canvas helpers now live in src/canvas.js
// === ENDSECTION: CANVAS API ===


// === SECTION: ADMIN ROUTES ===
app.get('/enroll/:slug', (req, res) => {
  try {
    const course = getCourse(req.params.slug);
    return res.redirect(302, course.canvas_enroll_url);
  } catch {
    return res.status(404).send('Unknown course.');
  }
});

const ADMIN_UI_DIR = path.join(__dirname, 'admin');
app.get('/admin', requireAdmin, (req, res) => res.redirect(302, '/admin/ui/'));
app.use('/admin/ui', requireAdmin, express.static(ADMIN_UI_DIR));

app.get('/admin/health', requireAdmin, (req, res) => {
  res.json({ ok: true, time: new Date().toISOString() });
});

app.get('/admin/api/courses', requireAdmin, (req, res) => {
  const all = loadCourses();
  const minimal = {};
  for (const [slug, c] of Object.entries(all)) {
    minimal[slug] = {
      title: c.title,
      canvas_course_id: c.canvas_course_id,
      verification_assignment_id: c.verification_assignment_id,
      open_at: c.open_at,
      close_at: c.close_at,
      purge_at: c.purge_at,
      protected_user_ids: c.protected_user_ids || []
    };
  }
  res.json(minimal);
});

app.post('/admin/jobs/sync/:slug', requireAdmin, async (req, res) => {
  try {
    const cfg = getCourse(req.params.slug);
    const base = process.env.CANVAS_BASE_URL;

    const enrollUrl =
      `${base}/api/v1/courses/${cfg.canvas_course_id}/enrollments` +
      `?type[]=StudentEnrollment&state[]=active&state[]=invited&per_page=100`;
    const enrollments = await canvasGetAll(enrollUrl);

    const subUrl =
      `${base}/api/v1/courses/${cfg.canvas_course_id}/assignments/${cfg.verification_assignment_id}/submissions?per_page=100`;
    const submissions = await canvasGetAll(subUrl);

    const submitted = submissions.filter(s => (s.workflow_state === 'submitted' || s.workflow_state === 'graded'));

    res.json({
      ok: true,
      slug: req.params.slug,
      canvas_course_id: cfg.canvas_course_id,
      verification_assignment_id: cfg.verification_assignment_id,
      counts: {
        enrollments: enrollments.length,
        submissions_total: submissions.length,
        submissions_submitted: submitted.length
      },
      sample: submitted.slice(0, 5).map(s => ({
        user_id: s.user_id,
        workflow_state: s.workflow_state,
        submitted_at: s.submitted_at
      }))
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/admin/jobs/purge/:slug', requireAdmin, async (req, res) => {
  try {
    const cfg = getCourse(req.params.slug);
    const enrollments = await fetchStudentEnrollments(cfg);
    const { deletable, skipped } = splitEnrollments(enrollments, cfg);

    res.json({
      ok: true,
      mode: 'dry-run',
      slug: req.params.slug,
      canvas_course_id: cfg.canvas_course_id,
      will_remove_enrollments: deletable.length,
      will_skip_protected: skipped.length,
      sample: [...deletable.slice(0, 8), ...skipped.slice(0, 2)].slice(0, 10).map(e => ({
        enrollment_id: e.id,
        user_id: e.user_id,
        type: e.type,
        enrollment_state: e.enrollment_state,
        protected: protectedUserSet(cfg).has(Number(e.user_id))
      }))
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/jobs/purge/:slug', requireAdmin, async (req, res) => {
  try {
    const { confirm } = req.body || {};
    if (confirm !== 'PURGE') {
      return res.status(400).json({ error: 'Missing confirm. Send JSON body: {"confirm":"PURGE"}' });
    }

    const cfg = getCourse(req.params.slug);
    const result = await purgeCourseEnrollments(cfg);

    res.json({
      ok: result.failures.length === 0,
      mode: 'execute',
      slug: req.params.slug,
      canvas_course_id: cfg.canvas_course_id,
      ...result
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/admin/jobs/reset_week/:slug', requireAdmin, async (req, res) => {
  try {
    const { confirm } = req.body || {};
    if (confirm !== 'RESET') {
      return res.status(400).json({ error: 'Missing confirm. Send JSON body: {"confirm":"RESET"}' });
    }

    const slug = req.params.slug;
    const cfg = getCourse(slug);

    const purge = await purgeCourseEnrollments(cfg);

    // safety: after manual reset, disable any scheduled autopurge for this slug
    autopurge.disable(slug);

    res.json({
      ok: purge.failures.length === 0,
      slug,
      canvas_course_id: cfg.canvas_course_id,
      action: 'reset_week',
      purge,
      autopurge_disabled: true
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
// === ENDSECTION: ADMIN ROUTES ===


// === SECTION: AUTOPURGE ===
const autopurge = createAutopurge({
  safeReadJson,
  safeWriteJson,
  getCourse,
  purgeCourseEnrollments
});

autopurge.registerRoutes(app, requireAdmin);
// === ENDSECTION: AUTOPURGE ===


// === SECTION: AI ===
app.post('/ai', aiLimiter, requireAiKey, async (req, res) => {
  const { query, personality } = req.body || {};
  const systemPrompt = personalities[personality] || 'You are a helpful AI assistant.';

  try {
    const apiResponse = await fetch('https://api.x.ai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.XAI_API_KEY}`
      },
      body: JSON.stringify({
        model: 'grok-4',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: String(query || '') }
        ],
        stream: false
      })
    });

    const data = await apiResponse.json();
    if (data.error) throw new Error(data.error.message);
    res.json({ response: data.choices?.[0]?.message?.content ?? '' });
  } catch (error) {
    res.status(500).json({ error: `AI call failed: ${error.message}` });
  }
});
// === ENDSECTION: AI ===


// === SECTION: SIGNUP ===
app.post('/signup', authLimiter, async (req, res) => {
  const { email, password } = req.body || {};
  try {
    const { data, error } = await supabase.auth.signUp({ email, password });
    if (error) throw error;
    res.json({ message: 'Sign-up successful', user: data.user });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
// === ENDSECTION: SIGNUP ===


// === SECTION: LISTEN/BOOTSTRAP ===
app.listen(port, () => {
  autopurge.init();
  console.log(`Server running at http://localhost:${port}`);
});
// === ENDSECTION: LISTEN/BOOTSTRAP ===

