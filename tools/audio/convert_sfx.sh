#!/usr/bin/env bash
# Переводит звуки из исходной папки (*.mp3 и др.) в AAC (.m4a) и выравнивает громкость.
#
# Использование: tools/audio/convert_sfx.sh <папка-с-исходниками> [папка-результата]
# Результат по умолчанию: assets/sfx. Нужен ffmpeg. Совместим с bash 3.2 (macOS).
#
# Громкость: у каждого файла измеряются средняя и пиковая громкость, затем усиление подбирается так, чтобы средняя
# была около TARGET_MEAN дБ, но пик не выше TARGET_PEAK дБ; усиление не больше MAX_BOOST и не меньше -MAX_CUT дБ.
# Короткие щелчки (меню, карта) без этого ограничения стали бы громче всего остального.
set -euo pipefail

TARGET_MEAN=-20
TARGET_PEAK=-1.5
MAX_BOOST=12
MAX_CUT=6

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Использование: $0 <папка-с-исходниками> [папка-результата]" >&2
  exit 2
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Нужен ffmpeg." >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/../.." && pwd)"
src="$1"
out="${2:-$root/assets/sfx}"
mkdir -p "$out"

count=0
for file in "$src"/*.mp3 "$src"/*.ogg "$src"/*.wav "$src"/*.flac; do
  [ -e "$file" ] || continue
  name="$(basename "${file%.*}")"
  stats="$(ffmpeg -hide_banner -nostats -i "$file" -af volumedetect -f null - 2>&1)"
  mean="$(echo "$stats" | sed -n 's/.*mean_volume: \(-\{0,1\}[0-9.]*\) dB.*/\1/p')"
  peak="$(echo "$stats" | sed -n 's/.*max_volume: \(-\{0,1\}[0-9.]*\) dB.*/\1/p')"
  gain="$(awk -v mean="$mean" -v peak="$peak" -v tm="$TARGET_MEAN" -v tp="$TARGET_PEAK" -v up="$MAX_BOOST" -v down="$MAX_CUT" '
    BEGIN {
      g = tm - mean
      if (peak + g > tp) g = tp - peak
      if (g > up) g = up
      if (g < -down) g = -down
      printf "%.1f", g
    }')"
  ffmpeg -hide_banner -loglevel error -y -i "$file" -vn -af "volume=${gain}dB" \
    -c:a aac -b:a 96k -ar 44100 -movflags +faststart "$out/$name.m4a"
  # SoundPool на Android не принимает звук больше 1 МБ после распаковки (44,1 кГц, 16 бит, стерео ≈ 172 КБ/с).
  seconds="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file")"
  if awk -v s="$seconds" 'BEGIN { exit !(s * 176400 > 1000000) }'; then
    echo "ВНИМАНИЕ: $name длиннее 5,6 с, SoundPool на Android может его не принять (ADR 0023)." >&2
  fi
  echo "$name: среднее $mean дБ, пик $peak дБ, усиление $gain дБ"
  count=$((count + 1))
done
echo "Готово: $count файлов в $out"
