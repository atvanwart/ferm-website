const express = require('express');
const bodyParser = require('body-parser');
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

app.use(helmet());
app.use(bodyParser.json());
app.use(express.static('public'));

// ---- Basic rate limits (small step; we’ll tune later) ----
const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 30 });  // signup/login
const aiLimiter   = rateLimit({ windowMs: 15 * 60 * 1000, max: 60 });  // AI calls

// ---- Admin Basic Auth middleware ----
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

// ---- Optional: lock AI endpoint with a shared secret ----
// This is NOT the final model. It’s a quick “stop the bleeding” gate.
// Later we’ll tie AI usage to paid seats + parent accounts.
function requireAiKey(req, res, next) {
  const provided = req.headers['x-fermentors-ai-key'];
  if (!process.env.AI_SHARED_SECRET) return next(); // if not set, don’t enforce
  if (provided && provided === process.env.AI_SHARED_SECRET) return next();
  return res.status(401).json({ error: 'Missing/invalid AI key.' });
}

// Load personalities
const personalities = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'personalities.json'), 'utf-8')
);

// Supabase client (anon key is fine for signup; do NOT use service role on the client)
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

// ---- Admin static page placeholder (we’ll add real admin UI later) ----
// Put an admin index at: /admin/index.html (served from /admin folder if you create it)
app.get('/admin', requireAdmin, (req, res) => {
  res.type('html').send(`
    <h1>Fermentors Admin (locked)</h1>
    <p>If you can see this, Basic Auth works.</p>
  `);
});

// AI endpoint (now rate-limited + optionally locked)
app.post('/ai', aiLimiter, requireAiKey, async (req, res) => {
  const { query, personality } = req.body;
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
          { role: 'user', content: query }
        ],
        stream: false
      })
    });

    const data = await apiResponse.json();
    if (data.error) throw new Error(data.error.message);
    res.json({ response: data.choices[0].message.content });
  } catch (error) {
    res.status(500).json({ error: `AI call failed: ${error.message}` });
  }
});

// Sign-up endpoint (rate-limited; still public)
app.post('/signup', authLimiter, async (req, res) => {
  const { email, password } = req.body;

  try {
    const { data, error } = await supabase.auth.signUp({ email, password });
    if (error) throw error;
    res.json({ message: 'Sign-up successful', user: data.user });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
