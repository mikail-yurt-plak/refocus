#!/bin/bash
# Simülatörde tüm dillerde vitrin ekran görüntülerini çeker.
# Kullanım: ./capture_screenshots.sh [locale ...]  (parametresiz: 20 dilin tamamı)
set -euo pipefail

cd "$(dirname "$0")"
UDID=$(xcrun simctl list devices | grep "ReFocus Marketing" | grep -oE '[0-9A-F-]{36}' | head -1)
BUNDLE="com.mikailyurt.refocus"

# store locale -> AppleLanguages kodu (macOS bash 3.2 uyumlu)
lang_for() {
  case "$1" in
    en-US) echo en ;;
    de-DE) echo de ;;
    fr-FR) echo fr ;;
    es-ES) echo es ;;
    nl-NL) echo nl ;;
    pt-BR) echo pt ;;
    ar-SA) echo ar ;;
    *) echo "$1" ;;
  esac
}

LOCALES=("$@")
if [ ${#LOCALES[@]} -eq 0 ]; then
  LOCALES=(tr en-US de-DE fr-FR es-ES it nl-NL pl pt-BR ru ar-SA hi id ja ko th uk vi zh-Hans zh-Hant)
fi

xcrun simctl status_bar "$UDID" override --time "9:41" --batteryLevel 100 \
  --batteryState charged --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true

for LOCALE in "${LOCALES[@]}"; do
  LANG_CODE=$(lang_for "$LOCALE")
  OUT="raw-sim/$LOCALE"
  mkdir -p "$OUT"
  for SHOT in 1 2 3 4 5 6; do
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
    xcrun simctl launch "$UDID" "$BUNDLE" \
      -marketingShot "$SHOT" -AppleLanguages "($LANG_CODE)" >/dev/null
    sleep 3
    xcrun simctl io "$UDID" screenshot "$OUT/$SHOT.png" >/dev/null
  done
  echo "cekildi: $LOCALE"
done
