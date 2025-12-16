'use strict';

// SECTION INDEX (src/courses.js)
// 1) IMPORTS + CONSTS
// 2) loadCourses
// 3) getCourse

// === SECTION: IMPORTS + CONSTS ===
const path = require('path');
const { safeReadJson } = require('./jsonStore');

const COURSES_PATH = path.join(__dirname, '..', 'courses.json');
// === ENDSECTION: IMPORTS + CONSTS ===


// === SECTION: loadCourses ===
function loadCourses() {
  return safeReadJson(COURSES_PATH, {});
}
// === ENDSECTION: loadCourses ===


// === SECTION: getCourse ===
function getCourse(slug) {
  const all = loadCourses();
  const course = all[slug];
  if (!course) throw new Error(`Unknown course slug: ${slug}`);
  return course;
}
// === ENDSECTION: getCourse ===

module.exports = { COURSES_PATH, loadCourses, getCourse };
