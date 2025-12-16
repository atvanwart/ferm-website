(() => {
  const $ = (id) => document.getElementById(id);

  const out = $('out');
  const flash = $('flash');

  const serverNow = $('serverNow');
  const serverNowLocal = $('serverNowLocal');

  const courseSelect = $('courseSelect');
  const slugEl = $('slug');

  const courseTitle = $('courseTitle');
  const courseId = $('courseId');
  const assignId = $('assignId');
  const protectedIds = $('protectedIds');

  const apEnabled = $('apEnabled');
  const apRunAt = $('apRunAt');
  const apLastRun = $('apLastRun');
  const apLastStatus = $('apLastStatus');
  const apLastRemoved = $('apLastRemoved');
  const apLastFailures = $('apLastFailures');

  const runAtLocal = $('runAtLocal');

  function show(obj) {
    out.textContent = typeof obj === 'string' ? obj : JSON.stringify(obj, null, 2);
  }

  function toast(msg) {
    flash.textContent = msg;
    setTimeout(() => { flash.textContent = ''; }, 1800);
  }

  async function fetchJson(url, opts = {}) {
    const r = await fetch(url, {
      ...opts,
      headers: {
        ...(opts.headers || {}),
        ...(opts.body ? { 'Content-Type': 'application/json' } : {})
      }
    });

    const text = await r.text();
    let data = null;
    try { data = JSON.parse(text); } catch { data = { raw: text }; }

    if (!r.ok) {
      const msg = data?.error || data?.raw || `${r.status} ${r.statusText}`;
      throw new Error(msg);
    }
    return data;
  }

  function currentSlug() {
    return (slugEl.value || '').trim();
  }

  async function refreshClock() {
    const data = await fetchJson('/admin/api/now');
    serverNow.textContent = data.utc || '—';

    const browserLocal = (() => {
      try { return new Date(data.epoch_ms).toLocaleString(); } catch { return '—'; }
    })();

    serverNowLocal.textContent = `Chicago: ${data.chicago || '—'}  •  Browser: ${browserLocal}`;
    return data;
  }

  function getAutoMode() {
    const checked = document.querySelector('input[name="apMode"]:checked');
    return checked ? checked.value : 'off';
  }

  async function loadCoursesList() {
    const data = await fetchJson('/admin/api/courses');
    const slugs = Object.keys(data).sort();

    courseSelect.innerHTML = '';
    for (const slug of slugs) {
      const opt = document.createElement('option');
      opt.value = slug;
      opt.textContent = `${slug} — ${data[slug].title || ''}`.trim();
      courseSelect.appendChild(opt);
    }

    const cur = currentSlug();
    if (cur && data[cur]) {
      courseSelect.value = cur;
    } else if (slugs.length) {
      courseSelect.value = slugs[0];
      slugEl.value = slugs[0];
    }

    return data;
  }

  function renderCourseInfo(courseMap) {
    const slug = currentSlug();
    const c = courseMap?.[slug];
    if (!c) {
      courseTitle.textContent = '—';
      courseId.textContent = '—';
      assignId.textContent = '—';
      protectedIds.textContent = '—';
      return;
    }
    courseTitle.textContent = c.title || '—';
    courseId.textContent = String(c.canvas_course_id ?? '—');
    assignId.textContent = String(c.verification_assignment_id ?? '—');
    protectedIds.textContent = (c.protected_user_ids || []).length
      ? (c.protected_user_ids || []).join(', ')
      : '(none)';
  }

  async function refreshStatus() {
    const slug = currentSlug();
    if (!slug) return show('Missing slug');

    const ap = await fetchJson(`/admin/api/autopurge/${encodeURIComponent(slug)}`);

    apEnabled.textContent = ap.enabled ? 'true' : 'false';
    apRunAt.textContent = ap.run_at || '—';
    apLastRun.textContent = ap.last_run_at || '—';
    apLastStatus.textContent = ap.last_status || '—';
    apLastRemoved.textContent = ap.last_removed ?? '—';
    apLastFailures.textContent = ap.last_failures_count ?? '—';

    return ap;
  }

  async function runSync() {
    const slug = currentSlug();
    if (!slug) return show('Missing slug');
    show('Running sync…');
    const res = await fetchJson(`/admin/jobs/sync/${encodeURIComponent(slug)}`, { method: 'POST' });
    show(res);
  }

  async function purgePreview() {
    const slug = currentSlug();
    if (!slug) return show('Missing slug');
    show('Running purge preview…');
    const res = await fetchJson(`/admin/jobs/purge/${encodeURIComponent(slug)}`);
    show(res);
  }

  async function purgeExecute() {
    const slug = currentSlug();
    if (!slug) return show('Missing slug');

    const typed = prompt(`Type PURGE to remove student enrollments from Canvas for:\n\n${slug}\n\n(Protected user IDs will be skipped.)`);
    if (typed !== 'PURGE') return toast('Cancelled.');

    show('Running purge execute…');
    const res = await fetchJson(`/admin/jobs/purge/${encodeURIComponent(slug)}`, {
      method: 'POST',
      body: JSON.stringify({ confirm: 'PURGE' })
    });
    show(res);
    await refreshStatus();
  }

  async function resetWeek() {
    const slug = currentSlug();
    if (!slug) return show('Missing slug');

    const typed = prompt(`Type RESET to run Reset Week for:\n\n${slug}\n\nThis purges enrollments and disables auto-purge.`);
    if (typed !== 'RESET') return toast('Cancelled.');

    show('Running Reset Week…');
    const res = await fetchJson(`/admin/jobs/reset_week/${encodeURIComponent(slug)}`, {
      method: 'POST',
      body: JSON.stringify({ confirm: 'RESET' })
    });
    show(res);
    await refreshStatus();
  }

  async function saveAutoPurge() {
    const slug = currentSlug();
    if (!slug) return show('Missing slug');

    const mode = getAutoMode();
    const enable = (mode === 'on');

    if (!enable) {
      show('Auto-purge is Off. Use Disable to clear any schedule.');
      return;
    }

    const val = (runAtLocal.value || '').trim();
    if (!val) return show('Pick a Run at (local time) first.');

    const d = new Date(val);
    if (!Number.isFinite(d.getTime())) return show('Invalid date/time.');

    const isoUtc = d.toISOString();

    show('Saving auto-purge…');
    const res = await fetchJson(`/admin/api/autopurge/${encodeURIComponent(slug)}`, {
      method: 'POST',
      body: JSON.stringify({ enabled: true, run_at: isoUtc })
    });
    show(res);
    await refreshStatus();
  }

  async function disableAutoPurge() {
    const slug = currentSlug();
    if (!slug) return show('Missing slug');

    show('Disabling auto-purge…');
    const res = await fetchJson(`/admin/api/autopurge/${encodeURIComponent(slug)}`, {
      method: 'POST',
      body: JSON.stringify({ enabled: false })
    });
    show(res);
    await refreshStatus();
  }

  async function copyOutput() {
    try {
      await navigator.clipboard.writeText(out.textContent || '');
      toast('Copied.');
    } catch {
      toast('Copy failed (browser permissions).');
    }
  }

  async function boot() {
    show({ ready: true });

    const courseMap = await loadCoursesList();
    renderCourseInfo(courseMap);

    try {
      await refreshClock();
      await refreshStatus();
    } catch (e) {
      show({ error: e.message });
    }

    // keep clock fresh
    setInterval(() => refreshClock().catch(() => {}), 10000);

    courseSelect.addEventListener('change', async () => {
      slugEl.value = courseSelect.value;
      renderCourseInfo(courseMap);
      try { await refreshStatus(); } catch (e) { show({ error: e.message }); }
    });

    $('btnLoad').addEventListener('click', async () => {
      const slug = currentSlug();
      if (courseMap[slug]) {
        courseSelect.value = slug;
        renderCourseInfo(courseMap);
      }
      try { await refreshStatus(); } catch (e) { show({ error: e.message }); }
    });

    $('btnRefresh').addEventListener('click', async () => {
      try { await refreshClock(); await refreshStatus(); toast('Refreshed.'); } catch (e) { show({ error: e.message }); }
    });

    $('btnSync').addEventListener('click', async () => {
      try { await runSync(); toast('Done.'); } catch (e) { show({ error: e.message }); }
    });

    $('btnPurgePreview').addEventListener('click', async () => {
      try { await purgePreview(); } catch (e) { show({ error: e.message }); }
    });

    $('btnPurge').addEventListener('click', async () => {
      try { await purgeExecute(); } catch (e) { show({ error: e.message }); }
    });

    $('btnResetWeek').addEventListener('click', async () => {
      try { await resetWeek(); } catch (e) { show({ error: e.message }); }
    });

    $('btnSaveAutoPurge').addEventListener('click', async () => {
      try { await saveAutoPurge(); } catch (e) { show({ error: e.message }); }
    });

    $('btnDisableAutoPurge').addEventListener('click', async () => {
      try { await disableAutoPurge(); toast('Disabled.'); } catch (e) { show({ error: e.message }); }
    });

    $('btnCopy').addEventListener('click', copyOutput);
  }

  boot().catch(err => show({ error: err.message }));
})();
