#!/usr/bin/env bash
# SECTION INDEX
# DR.1  drive wrappers (allowlist-only, no broad sync)

# SECTION:DRIVE_WRAPPERS
drive_pull_seed_cmd() {
  local name="${1:-}"
  [ -n "$name" ] || die "Usage: ./FERM_RUNBOOK.sh drive-pull-seed <PARKING_LOT.md|LESSONS_LEARNED.md|SESSION_SNAPSHOTS.md>"

  case "$name" in
    PARKING_LOT.md|LESSONS_LEARNED.md|SESSION_SNAPSHOTS.md) ;;
    *) die "Refusing: '$name' not in allowlist (PARKING_LOT.md, LESSONS_LEARNED.md, SESSION_SNAPSHOTS.md)";;
  esac

  need rclone

  local stage_dir="$ROOT/_drive_stage"
  mkdir -p "$stage_dir"

  local dst="$stage_dir/$name"
  echo "Drive pull (seed allowlist): fermdrive:$name -> $dst"
  rclone copyto "fermdrive:$name" "$dst" --progress

  clip_cmd "$dst"
  echo "OK: pulled + clipped $name"
}

drive_push_seed_cmd() {
  local name="${1:-}"
  local force_flag="${2:-}"
  [ -n "$name" ] || die "Usage: ./FERM_RUNBOOK.sh drive-push-seed <PARKING_LOT.md|LESSONS_LEARNED.md|SESSION_SNAPSHOTS.md> [--force]"

  case "$name" in
    PARKING_LOT.md|LESSONS_LEARNED.md|SESSION_SNAPSHOTS.md) ;;
    *) die "Refusing: '$name' not in allowlist (PARKING_LOT.md, LESSONS_LEARNED.md, SESSION_SNAPSHOTS.md)";;
  esac

  if [ -n "$force_flag" ] && [ "$force_flag" != "--force" ]; then
    die "Usage: ./FERM_RUNBOOK.sh drive-push-seed <seedfile> [--force]"
  fi

  need rclone

  local stage_dir="$ROOT/_drive_stage"
  mkdir -p "$stage_dir"

  local src="$stage_dir/$name"
  [ -f "$src" ] || die "Local staged file not found: $src (pull first, or place the file there intentionally)"

  # Robust remote existence check
  if rclone lsf "fermdrive:" --files-only 2>/dev/null | grep -Fxq "$name"; then
    if [ "$force_flag" != "--force" ]; then
      die "Refusing to overwrite existing remote file '$name' without --force"
    fi
    echo "WARNING: overwriting remote '$name' (forced)"
  fi

  echo "Drive push (seed allowlist): $src -> fermdrive:$name"
  rclone copyto "$src" "fermdrive:$name" --progress

  echo "OK: pushed $name"
}
# ENDSECTION:DRIVE_WRAPPERS
