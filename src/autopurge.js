'use strict';

// SECTION INDEX (src/autopurge.js)
// 1) STORE + TIMERS
// 2) SCHEDULER
// 3) ADMIN API ROUTES

// === SECTION: STORE + TIMERS ===
const path = require('path');
const fs = require('fs');

function createAutopurge(deps) {
  const { safeReadJson, safeWriteJson, getCourse, purgeCourseEnrollments } = deps;

  const AUTOPURGE_PATH = path.join(__dirname, '..', 'autopurge.json');
  const timers = new Map(); // slug -> Timeout

  function loadAll() {
    return safeReadJson(AUTOPURGE_PATH, {});
  }

  function saveAll(obj) {
    safeWriteJson(AUTOPURGE_PATH, obj);
  }

  function clearTimer(slug) {
    const t = timers.get(slug);
    if (t) clearTimeout(t);
    timers.delete(slug);
  }

  function disable(slug) {
    const all = loadAll();
    all[slug] = { ...(all[slug] || {}), enabled: false, run_at: null };
    saveAll(all);
    clearTimer(slug);
  }
  // === ENDSECTION: STORE + TIMERS ===


  // === SECTION: SCHEDULER ===
  function scheduleOneShot(slug) {
    clearTimer(slug);

    const all = loadAll();
    const cfg = all[slug];
    if (!cfg || !cfg.enabled || !cfg.run_at) return;

    const runMs = Date.parse(cfg.run_at);
    if (!Number.isFinite(runMs)) return;

    const delay = runMs - Date.now();
    if (delay <= 0) return; // past time; ignore

    const timer = setTimeout(async () => {
      const started = new Date().toISOString();
      let status = 'ok';
      let removed = 0;
      let failuresCount = 0;

      try {
        const courseCfg = getCourse(slug);
        const result = await purgeCourseEnrollments(courseCfg);
        removed = (result.deleted || 0) + (result.concluded || 0);
        failuresCount = result.failures.length;
        status = failuresCount === 0 ? 'ok' : 'partial_fail';
      } catch (e) {
        status = `error: ${e.message}`;
      }

      const latest = loadAll();
      latest[slug] = {
        ...(latest[slug] || {}),
        enabled: false,
        run_at: null,
        last_run_at: started,
        last_status: status,
        last_removed: removed,
        last_failures_count: failuresCount
      };
      saveAll(latest);
      clearTimer(slug);
    }, delay);

    timers.set(slug, timer);
  }

  function init() {
    if (!fs.existsSync(AUTOPURGE_PATH)) safeWriteJson(AUTOPURGE_PATH, {});
    const all = loadAll();
    for (const slug of Object.keys(all)) scheduleOneShot(slug);
  }
  // === ENDSECTION: SCHEDULER ===


  // === SECTION: ADMIN API ROUTES ===
  function registerRoutes(app, requireAdmin) {
    // status
    app.get('/admin/api/autopurge/:slug', requireAdmin, (req, res) => {
      try {
        getCourse(req.params.slug);

        const all = loadAll();
        const cfg = all[req.params.slug] || {};
        res.json({
          ok: true,
          slug: req.params.slug,
          server_now: new Date().toISOString(),
          enabled: !!cfg.enabled,
          run_at: cfg.run_at || null,
          last_run_at: cfg.last_run_at || null,
          last_status: cfg.last_status || null,
          last_removed: cfg.last_removed || null,
          last_failures_count: cfg.last_failures_count || null
        });
      } catch (e) {
        res.status(400).json({ error: e.message });
      }
    });

    // set one-shot schedule
    app.post('/admin/api/autopurge/:slug', requireAdmin, (req, res) => {
      try {
        getCourse(req.params.slug);

        const { enabled, run_at } = req.body || {};
        const wantEnabled = !!enabled;

        if (wantEnabled) {
          if (!run_at) return res.status(400).json({ error: 'enabled=true requires run_at (ISO string).' });
          const ms = Date.parse(run_at);
          if (!Number.isFinite(ms)) return res.status(400).json({ error: 'run_at is not a valid ISO datetime.' });
          if (ms <= Date.now()) return res.status(400).json({ error: 'run_at must be in the future.' });
        }

        const all = loadAll();
        all[req.params.slug] = {
          ...(all[req.params.slug] || {}),
          enabled: wantEnabled,
          run_at: wantEnabled ? run_at : null
        };
        saveAll(all);

        scheduleOneShot(req.params.slug);

        res.json({
          ok: true,
          slug: req.params.slug,
          enabled: wantEnabled,
          run_at: wantEnabled ? run_at : null
        });
      } catch (e) {
        res.status(400).json({ error: e.message });
      }
    });
  }
  // === ENDSECTION: ADMIN API ROUTES ===

  return {
    AUTOPURGE_PATH,
    loadAll,
    saveAll,
    clearTimer,
    disable,
    scheduleOneShot,
    init,
    registerRoutes
  };
}

module.exports = { createAutopurge };
