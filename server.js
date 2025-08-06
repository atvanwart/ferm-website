const express = require('express');
const bodyParser = require('body-parser');
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const app = express();
const port = 3000;

app.use(bodyParser.json());
app.use(express.static('public'));

// Load personalities
const personalities = JSON.parse(fs.readFileSync(path.join(__dirname, 'personalities.json'), 'utf-8'));

// Supabase client
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

// AI endpoint
app.post('/ai', async (req, res) => {
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

// Sign-up endpoint (Supabase auth proxy)
app.post('/signup', async (req, res) => {
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
