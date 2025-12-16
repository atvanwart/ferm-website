'use strict';

// === SECTION: CANVAS (SERVICE) ===============================================
// This module contains Canvas API helpers + purge logic.
// It intentionally does NOT know about Express routes, files, or autopurge.
// =============================================================================

function canvasClientFromEnv() {
  const baseUrl = process.env.CANVAS_BASE_URL;
  const token = process.env.CANVAS_TOKEN;
  if (!baseUrl) throw new Error('Missing CANVAS_BASE_URL in .env');
  if (!token) throw new Error('Missing CANVAS_TOKEN in .env');
  return { baseUrl, token };
}

function canvasHeaders(client) {
  return {
    'Authorization': `Bearer ${client.token}`,
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

async function canvasGetAll(client, url) {
  const out = [];
  let next = url;

  while (next) {
    const r = await fetch(next, { headers: canvasHeaders(client) });
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

async function enrollmentTask(client, courseId, enrollmentId, task) {
  const url =
    `${client.baseUrl}/api/v1/courses/${courseId}/enrollments/${enrollmentId}` +
    `?task=${encodeURIComponent(task)}`;

  const r = await fetch(url, { method: 'DELETE', headers: canvasHeaders(client) });
  if (!r.ok) {
    const text = await r.text();
    throw new Error(`Canvas DELETE failed ${r.status}: ${text.slice(0, 300)}`);
  }

  // Canvas may return JSON or blank; handle both.
  try { return await r.json(); } catch { return { ok: true }; }
}

function protectedUserSet(courseCfg) {
  return new Set((courseCfg.protected_user_ids || []).map(x => Number(x)));
}

async function fetchStudentEnrollments(client, courseCfg) {
  const url =
    `${client.baseUrl}/api/v1/courses/${courseCfg.canvas_course_id}/enrollments` +
    `?type[]=StudentEnrollment&state[]=active&state[]=invited&state[]=completed&per_page=100`;
  return canvasGetAll(client, url);
}

function splitEnrollments(enrollments, courseCfg) {
  const pset = protectedUserSet(courseCfg);
  const skipped = [];
  const deletable = [];

  for (const e of enrollments) {
    const uid = Number(e.user_id);
    if (pset.has(uid)) skipped.push(e);
    else deletable.push(e);
  }
  return { deletable, skipped };
}

async function purgeCourseEnrollments(client, courseCfg) {
  const enrollments = await fetchStudentEnrollments(client, courseCfg);
  const { deletable, skipped } = splitEnrollments(enrollments, courseCfg);

  let deleted = 0;
  let concluded = 0;
  const failures = [];

  for (const e of deletable) {
    try {
      await enrollmentTask(client, courseCfg.canvas_course_id, e.id, 'delete');
      deleted += 1;
    } catch (err) {
      // Fallback: delete can be blocked for some enrollments; conclude still clears roster
      try {
        await enrollmentTask(client, courseCfg.canvas_course_id, e.id, 'conclude');
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

async function fetchVerificationSubmissions(client, courseCfg) {
  const url =
    `${client.baseUrl}/api/v1/courses/${courseCfg.canvas_course_id}` +
    `/assignments/${courseCfg.verification_assignment_id}/submissions?per_page=100`;
  return canvasGetAll(client, url);
}

// === ENDSECTION: CANVAS (SERVICE) ===========================================

module.exports = {
  canvasClientFromEnv,
  canvasGetAll,
  fetchStudentEnrollments,
  splitEnrollments,
  protectedUserSet,
  purgeCourseEnrollments,
  fetchVerificationSubmissions,
  enrollmentTask
};
