#!/usr/bin/env bash
# ============================================================
# Personal RGB20S trim: a single-screen handheld used mostly for GBA.
#
#   rgb20s_trim.sh apply <root>   trim a root filesystem tree (mounted image
#                                 root or OTA payload root):
#                                 - drop every EmulationStation system that is
#                                   not in KEEP_SYSTEMS from es_systems*.cfg
#                                 - make mGBA the default GBA core
#                                 - delete emulators/cores only used by
#                                   dropped systems
#   rgb20s_trim.sh keeps <system> exit 0 when <system> is kept (used by
#                                 build_image.sh to skip PortMaster/JDK downloads)
#
# Set RGB20S_TRIM=0 in the environment to build the stock image instead.
# Upstream files are left untouched, so pulling upstream changes stays easy.
# ============================================================
set -euo pipefail

# ---------------- configuration ----------------
# EmulationStation <name> values to keep. To bring a system back, add its
# name (see /etc/emulationstation/es_systems.cfg). Examples:
#   nes famicom snes sfc mastersystem megadrive genesis gamegear  (8/16-bit)
#   psx                                                           (PlayStation)
#   arcade fbneo neogeo mame2003 cps1 cps2                        (arcade)
#   ports                                                         (PortMaster)
KEEP_SYSTEMS="gb gbc gba sgb retroarch"

# Default GBA core: mGBA is accurate and emulates the cartridge real-time
# clock (Pokemon Ruby/Sapphire/Emerald berries, tides, events).
GBA_DEFAULT_CORE="mgba"

# "<systems that need it, comma separated>|<path relative to root>"
# A path is deleted only when none of its systems is kept. Globs allowed.
RA='home/ark/.config/retroarch/cores'
RA32='home/ark/.config/retroarch32/cores'
DELETE_RULES=(
  # NDS - needs two screens
  "nds|opt/drastic"
  "nds|opt/drastic-kk"
  "nds|opt/DSperate"
  "nds|usr/local/bin/drastic.sh"
  "nds|usr/local/bin/drastic_kk.sh"
  "nds|usr/local/bin/choose_drastic_ver.sh"
  "nds|$RA/melonds*_libretro.so"
  "nds|$RA/desmume*_libretro.so"
  # PSP
  "ppsspp,pspminis|opt/ppsspp"
  "ppsspp,pspminis|opt/ppsspp-2021"
  "ppsspp,pspminis|opt/ppssppgo"
  "ppsspp,pspminis|usr/local/bin/ppsspp.sh"
  "ppsspp,pspminis|$RA/ppsspp_libretro.so"
  # Dreamcast / Naomi / Atomiswave
  "dreamcast,naomi,Sega Atomiswave,vmu|opt/flycastsa"
  "dreamcast,naomi,Sega Atomiswave,vmu|usr/local/bin/dreamcast.sh"
  "dreamcast,naomi,Sega Atomiswave,vmu|usr/local/bin/naomi.sh"
  "dreamcast,naomi,Sega Atomiswave,vmu|usr/local/bin/atomiswave.sh"
  "dreamcast,naomi,Sega Atomiswave,vmu|$RA/flycast*_libretro.so"
  "dreamcast,naomi,Sega Atomiswave,vmu|$RA32/flycast*_libretro.so"
  # Saturn
  "saturn|opt/yabasanshiro"
  "saturn|usr/local/bin/saturn.sh"
  "saturn|$RA/yabasanshiro*_libretro.so"
  "saturn|$RA/yabause*_libretro.so"
  "saturn|$RA/mednafen_saturn*_libretro.so"
  "saturn|$RA32/yabadabadoo_libretro.so"
  # N64
  "n64,n64dd|opt/mupen64plus"
  "n64,n64dd|usr/local/bin/n64.sh"
  "n64,n64dd|$RA/mupen64plus*_libretro.so"
  "n64,n64dd|$RA/parallel_n64*_libretro.so"
  "n64,n64dd|$RA/km_ludicrousn64*_libretro.so"
  # PlayStation
  "psx|opt/duckstation"
  "psx|usr/local/bin/standalone-duckstation"
  "psx|$RA/pcsx_rearmed*_libretro.so"
  "psx|$RA32/pcsx_rearmed*_libretro.so"
  "psx|$RA/swanstation_libretro.so"
  "psx|$RA/duckstation_libretro.so"
  # Arcade
  "arcade,hbmame,cps1,cps2,cps3,mame2000,mame2003,mame2010,fbneo,neogeo|$RA/mame20*_libretro.so"
  "arcade,hbmame,cps1,cps2,cps3,mame2000,mame2003,mame2010,fbneo,neogeo|$RA32/mame20*_libretro.so*"
  "arcade,hbmame,cps1,cps2,cps3,mame2000,mame2003,mame2010,fbneo,neogeo|$RA/fbneo*_libretro.so"
  "arcade,hbmame,cps1,cps2,cps3,mame2000,mame2003,mame2010,fbneo,neogeo|$RA32/fbneo*_libretro.so"
  "arcade,hbmame,cps1,cps2,cps3,mame2000,mame2003,mame2010,fbneo,neogeo|$RA32/fbalpha*_libretro.so"
  "Daphne,alg|opt/hypseus-singe"
  "Daphne,alg|opt/hypseus"
  # Everything else that ships a standalone runtime
  "flash|opt/rufflesa"
  "flash|usr/local/bin/flash.sh"
  "krkr2|opt/krkr2"
  "j2me|opt/freej2mesa"
  "j2me|usr/local/bin/freej2me.sh"
  "j2me|$RA/freej2me_libretro.so"
  "onscripter|opt/onscripter"
  "onscripter|usr/local/bin/onscripter.sh"
  "onscripter|usr/local/bin/choose_ons_ver.sh"
  "pymo|opt/pymo"
  "pymo|usr/local/bin/pymo.sh"
  "pymo|usr/local/bin/cpymo"
  "scummvm|opt/scummvm"
  "openbor|opt/OpenBor"
  "openbor|opt/OpenBorFF"
  "gametank|opt/gametank"
  "native32|$RA/native32emu_libretro.so"
  "spmp8000|$RA/spmp8000emu_libretro.so"
  "bbk|$RA/bbkemu_libretro.so"
  "makecode|$RA/makecode_arcade_libretro.so"
)
# ------------------------------------------------

keeps() {
  local s
  for s in $KEEP_SYSTEMS; do [[ "$s" == "$1" ]] && return 0; done
  return 1
}

any_kept() {
  # $1: comma separated system names (names may contain spaces)
  local IFS=','
  local s
  for s in $1; do keeps "$s" && return 0; done
  return 1
}

filter_es_systems() {
  local cfg="$1"
  python3 - "$cfg" "$KEEP_SYSTEMS" "$GBA_DEFAULT_CORE" <<'PY'
import re, sys
path, keep, gba_core = sys.argv[1], set(sys.argv[2].split()), sys.argv[3]
with open(path, encoding="utf-8") as f:
    text = f.read()
block = re.compile(r"[ \t]*<system>.*?</system>[ \t]*\r?\n?", re.S)
dropped = []

def fix_gba(b):
    # Move the default core to the top of the retroarch core list
    def reorder(m):
        cores = re.findall(r"[ \t]*<core>.*?</core>\r?\n", m.group(2))
        want = [c for c in cores if re.search(r"<core>%s</core>" % re.escape(gba_core), c)]
        if not want:
            return m.group(0)
        rest = [c for c in cores if c not in want]
        return m.group(1) + "".join(want + rest) + m.group(3)
    return re.sub(r'(<emulator name="retroarch">\s*<cores>\r?\n)(.*?)([ \t]*</cores>)',
                  reorder, b, count=1, flags=re.S)

def repl(m):
    b = m.group(0)
    name = re.search(r"<name>(.*?)</name>", b).group(1).strip()
    if name not in keep:
        dropped.append(name)
        return ""
    return fix_gba(b) if name == "gba" else b

out = block.sub(repl, text)
with open(path, "w", encoding="utf-8", newline="") as f:
    f.write(out)
print("  %s: kept %d, dropped %d systems" % (path, out.count("<system>"), len(dropped)))
PY
}

apply() {
  local root="${1:?usage: $0 apply <root>}"
  [[ -d "$root/etc" ]] || { echo "[rgb20s_trim] not a root tree: $root" >&2; return 1; }
  echo "== RGB20S trim: keep [$KEEP_SYSTEMS] =="

  local cfg
  for cfg in "$root"/etc/emulationstation/es_systems.cfg{,.dual,.sd1,.sd2}; do
    [[ -f "$cfg" ]] && filter_es_systems "$cfg"
  done

  local rule systems pattern p
  shopt -s nullglob
  for rule in "${DELETE_RULES[@]}"; do
    systems="${rule%%|*}"
    pattern="${rule#*|}"
    any_kept "$systems" && continue
    # $pattern is unquoted on purpose so its glob expands
    for p in "$root"/$pattern; do
      [[ -e "$p" || -L "$p" ]] || continue
      rm -rf -- "$p"
      echo "  removed /${p#"$root"/}"
    done
  done
  shopt -u nullglob
}

case "${1:-}" in
  apply) shift; apply "$@" ;;
  keeps) keeps "${2:?usage: $0 keeps <system>}" ;;
  *) echo "usage: $0 apply <root> | keeps <system>" >&2; exit 2 ;;
esac
