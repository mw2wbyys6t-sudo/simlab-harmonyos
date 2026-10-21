#!/bin/sh
# Mutation proof for the landscape/compact axis assertions.
# Works on a scratch copy of the tree so the working tree is never touched.
set -u
REPO="F:/DevEcoProjects/SimLab"
SCRATCH="${TMPDIR:-/tmp}/simlab-mut"

rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"
cp -r "$REPO/entry" "$SCRATCH/entry"
cp -r "$REPO/tools" "$SCRATCH/tools"
L="$SCRATCH/entry/src/main/ets/common/Layout.ets"
cp "$L" "$L.pristine"

run_mutation() {
  name="$1"
  fn="$2"
  cp "$L.pristine" "$L"
  "$fn"
  echo "=== MUTATION: $name ==="
  ( cd "$SCRATCH" && node tools/physics-check/check.mjs 2>&1 | tail -16 )
  echo
}

mut_insetY() { sed -i '/static pageInsetY/,/^  }/ s/return 8;/return 16;/' "$L"; }
mut_compact() { sed -i 's/return heightVp > 0 \&\& heightVp < Layout.COMPACT_HEIGHT_MAX;/return false;/' "$L"; }
mut_threshold() { sed -i 's/static readonly COMPACT_HEIGHT_MAX: number = 500;/static readonly COMPACT_HEIGHT_MAX: number = 700;/' "$L"; }
mut_stacked() { sed -i '/static isStacked/,/^  }/ s/return cls === DeviceClass.PHONE \&\& !compact;/return cls === DeviceClass.PHONE;/' "$L"; }
mut_classify() { sed -i 's/if (Layout.isCompact(heightVp) \&\& widthVp < Layout.PAD_MAX) {/if (false) {/' "$L"; }
mut_insetX() { sed -i '/static pageInsetX/,/^  }/ s/return side > base ? side : base;/return base;/' "$L"; }
mut_scene() { sed -i '/static minSceneHeight/,/^  }/ s/return 150;/return 210;/' "$L"; }

run_mutation "pageInsetY compact not narrowed (8 -> 16)" mut_insetY
run_mutation "isCompact always false" mut_compact
run_mutation "compact height threshold 500 -> 700" mut_threshold
run_mutation "isStacked ignores the compact axis" mut_stacked
run_mutation "classify ignores the height axis" mut_classify
run_mutation "pageInsetX compact not widened" mut_insetX
run_mutation "minSceneHeight compact raised to 210" mut_scene

rm -rf "$SCRATCH"
