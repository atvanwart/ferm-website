/*
  SECTION INDEX (admin/ui.js)
  1) BOOTSTRAP (load ui.html into #app)
  2) DOM HELPERS + OUTPUT
  3) API HELPERS
  4) CLOCK (server+chicago+local)
  5) COURSES (load + bind)
  6) ACTIONS (sync/purge/reset)
  7) AUTOPURGE (status + set/disable)
*/

(() => {
  // === SECTION: BOOTSTRAP ===
  async function bootstrap() {
    const app = document.getElementById('app');
    const html = await (await fetch('ui.html', { cache: 'no-store' })).text();
    app.innerHTML = html;
    wireUi();
  }
  // === ENDSECTION: BOOTSTRAP ===

  function wireUi() {
    // === SECTION: DOM HELPERS + OUTPUT ===
    const $ = (id) => document.getElementById(id);

    const out = $('out');
    const flash = $('flash');
    const healthPill = $('healthPill');

    const serverUtc = $('serverUtc');
    const serverChicago = $('serverChicago');
    const browserLocal = $('browserLocal');

    const courseSelect = $('courseSelect');
    const slugEl = $('slug');

    const courseTitle = $('courseTitle');
    const courseCanvasId = $('courseCanvasId');
    const courseVerifyId = $('courseVerifyId');
    const courseProtected = $('courseProtected');

    const purgeConfirm = $('purgeConfirm');
    const btnPurgeExec = $('btnPurgeExec');
    const resetConfirm = $('resetConfirm');
    const btnResetWeek = $('btnResetWeek');

    const apEnabled = $('apEnabled');
    const apRunAt = $('apRunAt');
    const apRunAtLocal = $('apRunAtLocal');
    const apLastRun = $('apLastRun');
    const apLastStatus = $('apLastStatus');
    const apLastRemoved = $('apLastRemoved');
    const apControls = $('apControls');
    const apWhen = $('apWhen');

    const apModeRadios = Array.from(document.querySelectorAll('input[name="apMode"]'));

    function show(obj) {
      out.textContent = (typeof obj === 'string') ? obj : JSON.stringify(obj, null, 2);
    }

    function toast(msg, ok = true) {
      flash.hidden = false;
      flash.textContent = msg;
      flash.style.background = ok ? 'rgba(16,185,129,.14)' : 'rgba(220,38,38,.14)';
      setTimeout(() => { flash.hidden = true; }, 3500);
    }
    // === ENDSECTION: DOM HELPERS + OUTPUT ===

    // === SECTION: API HELPERS ===
    async function apiGet(url) {
      const r = await fetch(url, { cache: 'no-store' });
      const text = await r.text();
      try { return { ok: r.ok, status: r.status, json: JSON.parse(text) }; }
      catch { return { ok: r.ok, status: r.status, raw: text }; }
    }

    async function apiPost(url, bodyObj) {
      const r = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(bodyObj || {})
      });
      const text = await r.text();
      try { return { ok: r.ok, status: r.status, json: JSON.parse(text) }; }
      catch { return { ok: r.ok, status: r.status, raw: text }; }
    }

    function currentSlug() {
      const s = (slugEl.value || '').trim();
      return s;
    }
    // === ENDSECTION: API HELPERS ===

    // === SECTION: CLOCK ===
    function fmtChicago(d) {
      return new Intl.DateTimeFormat('en-US', {
        timeZone: 'America/Chicago',
        year: 'numeric', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit', second: '2-digit',
        hour12: false
      }).format(d);
    }

    function fmtLocal(d) {
      return d.toLocaleString();
    }

    async function refreshClock() {
      const res = await apiGet('/admin/health');
      if (!res.ok) {
        healthPill.textContent = `Health: ${res.status}`;
        healthPill.style.color = 'rgba(255,255,255,.70)';
        return;
      }

      const iso = res.json?.time || null;
      const d = iso ? new Date(iso) : new Date();

      serverUtc.textContent = iso || d.toISOString();
      serverChicago.textContent = fmtChicago(d);
      browserLocal.textContent = fmtLocal(new Date());

      healthPill.textContent = 'Health: OK';
      healthPill.style.color = 'rgba(255,255,255,.85)';
    }
    // === ENDSECTION: CLOCK ===

    // === SECTION: COURSES ===
    let courses = {};

    function setCourseDetails(slug) {
      const c = courses[slug] || null;
      if (!c) {
        courseTitle.textContent = '—';
        courseCanvasId.textContent = '—';
        courseVerifyId.textContent = '—';
        courseProtected.textContent = '—';
        return;
      }
      courseTitle.textContent = c.title || '—';
      courseCanvasId.textContent = String(c.canvas_course_id ?? '—');
      courseVerifyId.textContent = String(c.verification_assignment_id ?? '—');

      const p = Array.isArray(c.protected_user_ids) ? c.protected_user_ids : [];
      courseProtected.textContent = p.length ? p.join(', ') : '(none)';
    }

    async function loadCourses() {
      const res = await apiGet('/admin/api/courses');
      if (!res.ok) {
        toast(`Failed to load courses (${res.status})`, false);
        show(res.json || res.raw || res);
        return;
      }

      courses = res.json || {};
      const slugs = Object.keys(courses).sort();

      courseSelect.innerHTML = '';
      for (const slug of slugs) {
        const opt = document.createElement('option');
        opt.value = slug;
        opt.textContent = `${slug} — ${courses[slug].title || ''}`.trim();
        courseSelect.appendChild(opt);
      }

      // choose current slug if present; else first
      const want = currentSlug();
      const pick = (want && courses[want]) ? want : (slugs[0] || '');
      if (pick) {
        courseSelect.value = pick;
        slugEl.value = pick;
        setCourseDetails(pick);
      }

      toast('Courses loaded.');
      await refreshAutopurge();
    }
    // === ENDSECTION: COURSES ===

    // === SECTION: ACTIONS ===
    async function runSync() {
      const slug = currentSlug();
      if (!slug) return show('Missing slug');
      show('Running sync…');
      const res = await apiPost(`/admin/jobs/sync/${encodeURIComponent(slug)}`, {});
      show(res.json || res.raw || res);
      toast(res.ok ? 'Sync complete.' : `Sync failed (${res.status})`, res.ok);
    }

    async function purgePreview() {
      const slug = currentSlug();
      if (!slug) return show('Missing slug');
      show('Running purge preview…');
      const res = await apiGet(`/admin/jobs/purge/${encodeURIComponent(slug)}`);
      show(res.json || res.raw || res);
      toast(res.ok ? 'Preview loaded.' : `Preview failed (${res.status})`, res.ok);
    }

    async function purgeExecute() {
      const slug = currentSlug();
      if (!slug) return show('Missing slug');
      if ((purgeConfirm.value || '').trim() !== 'PURGE') return toast('Type PURGE to execute.', false);

      show('Executing purge…');
      const res = await apiPost(`/admin/jobs/purge/${encodeURIComponent(slug)}`, { confirm: 'PURGE' });
      show(res.json || res.raw || res);
      toast(res.ok ? 'Purge executed.' : `Purge failed (${res.status})`, res.ok);
      await refreshAutopurge();
    }

    async function resetWeek() {
      const slug = currentSlug();
      if (!slug) return show('Missing slug');
      if ((resetConfirm.value || '').trim() !== 'RESET') return toast('Type RESET to execute.', false);

      show('Resetting week (purge + disable auto-purge)…');
      const res = await apiPost(`/admin/jobs/reset_week/${encodeURIComponent(slug)}`, { confirm: 'RESET' });
      show(res.json || res.raw || res);
      toast(res.ok ? 'Reset week executed.' : `Reset week failed (${res.status})`, res.ok);

      // UI safety: force radio to off after reset
      apModeRadios.forEach(r => { if (r.value === 'off') r.checked = true; });
      apControls.style.display = 'none';

      await refreshAutopurge();
    }
    // === ENDSECTION: ACTIONS ===

    // === SECTION: AUTOPURGE ===
    function toLocalStringMaybe(iso) {
      if (!iso) return '—';
      const d = new Date(iso);
      if (Number.isNaN(d.getTime())) return '—';
      return d.toLocaleString();
    }

    async function refreshAutopurge() {
      const slug = currentSlug();
      if (!slug) return;

      const res = await apiGet(`/admin/api/autopurge/${encodeURIComponent(slug)}`);
      if (!res.ok) {
        apEnabled.textContent = '—';
        apRunAt.textContent = '—';
        apRunAtLocal.textContent = '—';
        apLastRun.textContent = '—';
        apLastStatus.textContent = '—';
        apLastRemoved.textContent = '—';
        toast(`Auto-purge status failed (${res.status})`, false);
        show(res.json || res.raw || res);
        return;
      }

      const j = res.json || {};
      apEnabled.textContent = String(!!j.enabled);
      apRunAt.textContent = j.run_at || '—';
      apRunAtLocal.textContent = toLocalStringMaybe(j.run_at);

      apLastRun.textContent = j.last_run_at || '—';
      apLastStatus.textContent = j.last_status || '—';
      apLastRemoved.textContent = (j.last_removed == null) ? '—' : String(j.last_removed);

      // keep radio + controls aligned
      const enabled = !!j.enabled;
      apModeRadios.forEach(r => { if (r.value === (enabled ? 'on' : 'off')) r.checked = true; });
      apControls.style.display = enabled ? 'flex' : 'none';
    }

    async function autopurgeSave() {
      const slug = currentSlug();
      if (!slug) return;

      const raw = (apWhen.value || '').trim();
      if (!raw) return toast('Pick a date/time first.', false);

      // datetime-local -> Date interpreted in browser local timezone -> convert to ISO UTC
      const d = new Date(raw);
      if (Number.isNaN(d.getTime())) return toast('Invalid date/time.', false);

      const run_at = d.toISOString();
      show({ info: 'Setting auto-purge (one-shot)…', slug, run_at });

      const res = await apiPost(`/admin/api/autopurge/${encodeURIComponent(slug)}`, {
        enabled: true,
        run_at
      });

      show(res.json || res.raw || res);
      toast(res.ok ? 'Auto-purge scheduled.' : `Auto-purge schedule failed (${res.status})`, res.ok);
      await refreshAutopurge();
    }

    async function autopurgeDisable() {
      const slug = currentSlug();
      if (!slug) return;

      show({ info: 'Disabling auto-purge…', slug });

      const res = await apiPost(`/admin/api/autopurge/${encodeURIComponent(slug)}`, {
        enabled: false
      });

      show(res.json || res.raw || res);
      toast(res.ok ? 'Auto-purge disabled.' : `Disable failed (${res.status})`, res.ok);

      apModeRadios.forEach(r => { if (r.value === 'off') r.checked = true; });
      apControls.style.display = 'none';

      await refreshAutopurge();
    }
    // === ENDSECTION: AUTOPURGE ===

    // === SECTION: EVENTS ===
    $('btnRefresh').addEventListener('click', async () => {
      await refreshClock();
      await refreshAutopurge();
    });

    $('btnLoadCourses').addEventListener('click', loadCourses);

    courseSelect.addEventListener('change', async () => {
      const slug = courseSelect.value;
      slugEl.value = slug;
      setCourseDetails(slug);
      await refreshAutopurge();
    });

    slugEl.addEventListener('change', async () => {
      const slug = currentSlug();
      if (courses[slug]) courseSelect.value = slug;
      setCourseDetails(slug);
      await refreshAutopurge();
    });

    $('btnSync').addEventListener('click', runSync);
    $('btnPurgePreview').addEventListener('click', purgePreview);

    purgeConfirm.addEventListener('input', () => {
      btnPurgeExec.disabled = (purgeConfirm.value || '').trim() !== 'PURGE';
    });
    $('btnPurgeExec').addEventListener('click', purgeExecute);

    resetConfirm.addEventListener('input', () => {
      btnResetWeek.disabled = (resetConfirm.value || '').trim() !== 'RESET';
    });
    $('btnResetWeek').addEventListener('click', resetWeek);

    apModeRadios.forEach(r => {
      r.addEventListener('change', () => {
        const on = apModeRadios.find(x => x.checked)?.value === 'on';
        apControls.style.display = on ? 'flex' : 'none';
        // NOTE: radio alone does NOT save; must click Save or Disable.
      });
    });

    $('btnApSave').addEventListener('click', autopurgeSave);
    $('btnApDisable').addEventListener('click', autopurgeDisable);
    $('btnApRefresh').addEventListener('click', refreshAutopurge);

    $('btnCopy').addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(out.textContent || '');
        toast('Output copied.');
      } catch {
        toast('Copy failed (browser permissions).', false);
      }
    });

    $('btnClear').addEventListener('click', () => show('{ "ready": true }'));

    // === ENDSECTION: EVENTS ===

    // === SECTION: INIT ===
    (async () => {
      await refreshClock();
      await loadCourses();
      await refreshAutopurge();

      // keep clocks fresh
      setInterval(async () => {
        await refreshClock();
      }, 5000);
    })().catch(err => {
      show({ error: err.message });
      toast(err.message, false);
    });
    // === ENDSECTION: INIT ===
  }

  bootstrap().catch((e) => {
    const app = document.getElementById('app');
    app.textContent = `Admin UI failed to load: ${e.message}`;
  });
})();
