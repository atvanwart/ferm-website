# Appendix Map

Generated: 2025-12-16T22:45:25-06:00
Root: /home/pendor/Adam_Van_Wart/fermentors/ferm-website

## Tree (files)

./admin/admin.css
./admin/admin.js
./admin/_bak/index.html.20251215_105913
./admin/index.html
./admin/ui.css
./admin/ui.html
./admin/ui.js
./APPENDIX_MAP.md
./autopurge.json
./check_canvas_env.js
./CHECKSUMS.sha256
./CNAME
./courses.json
./.env
./.fermentors-server.pid
./FERM_RUNBOOK.sh
./FERM_RUNBOOK_SH/00_core.sh
./FERM_RUNBOOK_SH/10_admin.sh
./FERM_RUNBOOK_SH/20_pack.sh
./FERM_RUNBOOK_SH/30_quality.sh
./FERM_RUNBOOK_SH/TEST_USER.sh
./ferm-tools.sh
./file
./.gitignore
./images/fermentors logo 000.png
./images/fermentors-logo.png
./images/placeholder.txt
./index.html
./package.json
./package-lock.json
./personalities.json
./PROJECT_STATE.md
./public/.gitignore
./public/index.html
./README.md
./RUNBOOK.md
./server.js
./server.js.bak.2025-12-14_141409
./server.js.bak.2025-12-14-171122
./server.js.new
./server.log
./serves
./src/autopurge.js
./src/canvas.js
./src/courses.js
./src/jsonStore.js
./src/services/canvas.js
./STRUCTURE.md
./supabase/migrations/20251216013449_handshake_model.sql
./supabase/.temp/cli-latest
./supabase/.temp/gotrue-version
./supabase/.temp/pooler-url
./supabase/.temp/postgres-version
./supabase/.temp/project-ref
./supabase/.temp/rest-version
./supabase/.temp/storage-migration
./supabase/.temp/storage-version

## Shell functions (runbook + modules)

FERM_RUNBOOK_SH/00_core.sh:16:clipboard_copy() { xclip -selection clipboard; }
FERM_RUNBOOK_SH/00_core.sh:17:clipboard_paste() { xclip -selection clipboard -o; }
FERM_RUNBOOK_SH/00_core.sh:19:clip_cmd() {
FERM_RUNBOOK_SH/00_core.sh:32:clipout_cmd() { clipboard_paste; }
FERM_RUNBOOK_SH/00_core.sh:6:die(){ echo "ERROR: $*" >&2; exit 1; }
FERM_RUNBOOK_SH/00_core.sh:7:need(){ command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }
FERM_RUNBOOK_SH/00_core.sh:9:is_secret_path() {
FERM_RUNBOOK_SH/10_admin.sh:13:admin_curl() {
FERM_RUNBOOK_SH/10_admin.sh:6:load_admin_creds() {
FERM_RUNBOOK_SH/20_pack.sh:32:pack_core_files() {
FERM_RUNBOOK_SH/20_pack.sh:6:pack_files() {
FERM_RUNBOOK_SH/30_quality.sh:113:checksum_cmd() {
FERM_RUNBOOK_SH/30_quality.sh:124:verify_cmd() { sha256sum -c CHECKSUMS.sha256; }
FERM_RUNBOOK_SH/30_quality.sh:126:doc_diff_cmd() {
FERM_RUNBOOK_SH/30_quality.sh:134:git_audit_cmd() {
FERM_RUNBOOK_SH/30_quality.sh:155:sumcheck_cmd() {
FERM_RUNBOOK_SH/30_quality.sh:202:appendix_cmd() {
FERM_RUNBOOK_SH/30_quality.sh:26:check_js() {
FERM_RUNBOOK_SH/30_quality.sh:40:check_json() {
FERM_RUNBOOK_SH/30_quality.sh:54:shell_leak() {
FERM_RUNBOOK_SH/30_quality.sh:59:size_audit() {
FERM_RUNBOOK_SH/30_quality.sh:6:git_counts() {
FERM_RUNBOOK_SH/TEST_USER.sh:16:need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command: $1" >&2; exit 1; }; }
FERM_RUNBOOK_SH/TEST_USER.sh:23:clip_maybe() {

## JS classes/functions (rough index)

server.js:62:function requireAdmin(req, res, next) {
server.js:74:function requireAiKey(req, res, next) {
server.js:105:function getBearerToken(req) {
server.js:111:function randBase32(nBytes) {
src/courses.js:17:function loadCourses() {
src/courses.js:24:function getCourse(slug) {
src/jsonStore.js:15:function safeReadJson(filePath, fallback) {
src/jsonStore.js:28:function safeWriteJson(filePath, obj) {
src/services/canvas.js:8:function canvasClientFromEnv() {
src/services/canvas.js:16:function canvasHeaders(client) {
src/services/canvas.js:23:function nextLink(linkHeader) {
src/services/canvas.js:66:function protectedUserSet(courseCfg) {
src/services/canvas.js:77:function splitEnrollments(enrollments, courseCfg) {
src/canvas.js:11:function canvasHeaders() {
src/canvas.js:19:function nextLink(linkHeader) {
src/canvas.js:67:function protectedUserSet(cfg) {
src/canvas.js:80:function splitEnrollments(enrollments, cfg) {
src/autopurge.js:12:function createAutopurge(deps) {
src/autopurge.js:18:  function loadAll() {
src/autopurge.js:22:  function saveAll(obj) {
src/autopurge.js:26:  function clearTimer(slug) {
src/autopurge.js:32:  function disable(slug) {
src/autopurge.js:42:  function scheduleOneShot(slug) {
src/autopurge.js:88:  function init() {
src/autopurge.js:97:  function registerRoutes(app, requireAdmin) {
admin/ui.js:22:  function wireUi() {
admin/ui.js:58:    function show(obj) {
admin/ui.js:62:    function toast(msg, ok = true) {
admin/ui.js:89:    function currentSlug() {
admin/ui.js:96:    function fmtChicago(d) {
admin/ui.js:105:    function fmtLocal(d) {
admin/ui.js:132:    function setCourseDetails(slug) {
admin/ui.js:232:    function toLocalStringMaybe(iso) {
admin/_bak/index.html.20251215_105913:201:  function show(obj) {
admin/_bak/index.html.20251215_105913:223:  function activeSlug() {
admin/_bak/index.html.20251215_105913:228:  function setAutoUiEnabled(enabled) {
admin/_bak/index.html.20251215_105913:233:  function isoToLocalDatetimeValue(iso) {
admin/admin.js:27:  function show(obj) {
admin/admin.js:31:  function toast(msg) {
admin/admin.js:56:  function currentSlug() {
admin/admin.js:72:  function getAutoMode() {
admin/admin.js:100:  function renderCourseInfo(courseMap) {
