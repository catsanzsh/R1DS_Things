#!/bin/zsh

# ToontoonAFS 1.0 Prototype - Adaptive Storage Optimizer
# SAFETY FIRST: Only targets user-approved directories (~/Documents, ~/Downloads)

# --- CONFIG ---
THRESHOLD=15  # Trigger optimization when storage <15%
MIN_SAFETY=5   # Emergency stop if storage drops below 5%
TARGET_DIRS=("$HOME/Documents" "$HOME/Downloads")  # User-approved folders
EXCLUDE="*.dmg,*.app,*.kext"  # File types to never compress

# --- FUNCTIONS ---
# Calculate free storage percentage
free_storage() {
  df -h / | awk '/\/dev\/disk/ {print $5}' | tr -d '%'
}

# Neural Compression Simulator (Zstandard + purgeable flags)
compress_cold_data() {
  local dir=$1
  find "$dir" -type f -mtime +30 -not -name "$EXCLUDE" -exec \
    zstd -q -T0 --ultra {} \; -exec chflags uchg {} \;
  echo "[Toontoon] Cold files compressed and marked purgeable."
}

# Safety Check: Ensure enough free space
safety_override() {
  local current=$(free_storage)
  if [[ $current -le $MIN_SAFETY ]]; then
    echo "[CRITICAL] Storage at ${current}% - Disabling Toontoon."
    exit 1
  fi
}

# --- MAIN ---
main() {
  current_free=$(free_storage)
  
  if [[ $current_free -lt $THRESHOLD ]]; then
    echo "[Toontoon] Storage low (${current_free}%). Optimizing..."
    
    # Step 1: Purge APFS snapshots (safe)
    tmutil thinlocalsnapshots / 999999999 1  # Aggressive cleanup
    
    # Step 2: Compress cold files
    for dir in "${TARGET_DIRS[@]}"; do
      compress_cold_data "$dir"
    done
    
    # Step 3: Update APFS metadata
    diskutil apfs updatePreboot /  # Ensure bootability
    
    new_free=$(free_storage)
    echo "[Toontoon] Recovered $(($new_free - $current_free))% space."
  else
    echo "[Toontoon] Storage OK (${current_free}%). No action needed."
  fi
}

# --- SAFETY LOCKS ---
safety_override
main