cd ~/Adam_Van_Wart/fermentors/ferm-website || exit 1

TS="$(date +%Y%m%d_%H%M%S)"

# 1) Stage new content (from clipboard)
./FERM_RUNBOOK.sh clipout > /tmp/PROJECT_STATE.md.new || exit 1

# 2) Sanity check (example: ensure file is non-empty)
test -s /tmp/PROJECT_STATE.md.new || { echo "ERROR: staged file is empty"; exit 1; }

# 3) Backup existing file
cp -a PROJECT_STATE.md "_old/PROJECT_STATE.md.$TS" || exit 1

# 4) Atomic replace
mv /tmp/PROJECT_STATE.md.new PROJECT_STATE.md || exit 1

# 5) Verify
./FERM_RUNBOOK.sh verify || exit 1
