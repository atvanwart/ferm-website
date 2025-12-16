'use strict';

// SECTION INDEX (src/jsonStore.js)
// 1) IMPORTS
// 2) safeReadJson
// 3) safeWriteJson

// === SECTION: IMPORTS ===
const fs = require('fs');
const path = require('path');
// === ENDSECTION: IMPORTS ===


// === SECTION: safeReadJson ===
function safeReadJson(filePath, fallback) {
  try {
    if (!fs.existsSync(filePath)) return fallback;
    return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
  } catch (e) {
    console.warn(`Warning: failed reading ${path.basename(filePath)}:`, e.message);
    return fallback;
  }
}
// === ENDSECTION: safeReadJson ===


// === SECTION: safeWriteJson ===
function safeWriteJson(filePath, obj) {
  fs.writeFileSync(filePath, JSON.stringify(obj, null, 2) + '\n', 'utf-8');
}
// === ENDSECTION: safeWriteJson ===

module.exports = { safeReadJson, safeWriteJson };
