'use strict';

// SECTION INDEX (src/canvas.js)
// 1) HEADERS + PAGINATION
// 2) canvasGetAll
// 3) ENROLLMENT TASKS
// 4) ENROLLMENT FETCH + SPLIT
// 5) PURGE

// === SECTION: HEADERS + PAGINATION ===
function canvasHeaders() {
  if (!process.env.CANVAS_TOKEN) throw new Error('Missing CANVAS_TOKEN in .env');
  return {
    'Authorization': `Bearer ${process.env.CANVAS_TOKEN}`,
    'Content-Type': 'application/json'
  };
}

function nextLink(linkHeader) {
  if (!linkHeader) return null;
  const parts = linkHeader.split(',').map(s => s.trim());
  for (const p of parts) {
    const m = p.match(/<([^>]+)>;\s*rel="next"/);
    if (m) return m[1];
  }
  return null;
}
// === ENDSECTION: HEADERS + PAGINATION ===


// === SECTION: canvasGetAll ===
async function canvasGetAll(url) {
  const out = [];
  let next = url;
  while (next) {
    const r = await fetch(next, { headers: canvasHeaders() });
    if (!r.ok) {
      const text = await r.text();
      throw new Error(`Canvas GET failed ${r.status}: ${text.slice(0, 300)}`);
    }
    const data = await r.json();
    if (Array.isArray(data)) out.push(...data);
    else out.push(data);
    next = nextLink(r.headers.get('link'));
  }
  return out;
}
// === ENDSECTION: canvasGetAll ===


// === SECTION: ENROLLMENT TASKS ===
async function canvasEnrollmentTask(courseId, enrollmentId, task) {
  const base = process.env.CANVAS_BASE_URL;
  if (!base) throw new Error('Missing CANVAS_BASE_URL in .env');
  const url = `${base}/api/v1/courses/${courseId}/enrollments/${enrollmentId}?task=${encodeURIComponent(task)}`;
  const r = await fetch(url, { method: 'DELETE', headers: canvasHeaders() });
  if (!r.ok) {
    const text = await r.text();
    throw new Error(`Canvas DELETE failed ${r.status}: ${text.slice(0, 300)}`);
  }
  try { return await r.json(); } catch { return { ok: true }; }
}
// === ENDSECTION: ENROLLMENT TASKS ===


// === SECTION: ENROLLMENT FETCH + SPLIT ===
function protectedUserSet(cfg) {
  return new Set((cfg.protected_user_ids || []).map(x => Number(x)));
}

async function fetchStudentEnrollments(cfg) {
  const base = process.env.CANVAS_BASE_URL;
  if (!base) throw new Error('Missing CANVAS_BASE_URL in .env');
  const enrollUrl =
    `${base}/api/v1/courses/${cfg.canvas_course_id}/enrollments` +
    `?type[]=StudentEnrollment&state[]=active&state[]=invited&state[]=completed&per_page=100`;
  return canvasGetAll(enrollUrl);
}

function splitEnrollments(enrollments, cfg) {
  const pset = protectedUserSet(cfg);
  const skipped = [];
  const deletable = [];

  for (const e of enrollments) {
    const uid = Number(e.user_id);
    if (pset.has(uid)) skipped.push(e);
    else deletable.push(e);
  }
  return { deletable, skipped };
}
// === ENDSECTION: ENROLLMENT FETCH + SPLIT ===


// === SECTION: PURGE ===
async function purgeCourseEnrollments(cfg) {
  const enrollments = await fetchStudentEnrollments(cfg);
  const { deletable, skipped } = splitEnrollments(enrollments, cfg);

  let deleted = 0;
  let concluded = 0;
  const failures = [];

  for (const e of deletable) {
    try {
      await canvasEnrollmentTask(cfg.canvas_course_id, e.id, 'delete');
      deleted += 1;
    } catch (err) {
      // fallback: conclude if delete is blocked
      try {
        await canvasEnrollmentTask(cfg.canvas_course_id, e.id, 'conclude');
        concluded += 1;
      } catch (err2) {
        failures.push({ enrollment_id: e.id, user_id: e.user_id, error: err2.message });
      }
    }
  }

  return {
    found_enrollments: enrollments.length,
    will_act_on: deletable.length,
    skipped_protected: skipped.length,
    deleted,
    concluded,
    failures
  };
}
// === ENDSECTION: PURGE ===

module.exports = {
  canvasGetAll,
  protectedUserSet,
  fetchStudentEnrollments,
  splitEnrollments,
  purgeCourseEnrollments
};
