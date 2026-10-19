#!/usr/bin/env bash
# Переводит фоновую музыку в AAC (.m4a) для assets/music.
#
# Использование: tools/audio/convert_music.sh <папка-с-исходниками> [папка-результата]
# Список композиций и имена результата: tools/audio/music_tracks.txt (строка «имя|исходный файл без расширения»).
# Результат по умолчанию: assets/music. Нужен ffmpeg. Совместим с bash 3.2 (macOS).
#
# Громкость выравнивается по воспринимаемой (loudnorm, около -18 LUFS), чтобы композиции не отличались друг от друга;
# обложки и теги выбрасываются. Битрейт 96 кбит/с: для фоновой музыки на телефоне этого хватает, а набор остаётся
# небольшим.
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Использование: $0 <папка-с-исходниками> [папка-результата]" >&2
  exit 2
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Нужен ffmpeg." >&2
  exit 1
fi

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
src="$1"
out="${2:-$root/assets/music}"
mkdir -p "$out"

count=0
while IFS='|' read -r slug source; do
  case "$slug" in ''|'#'*) continue ;; esac
  file="$src/$source.mp3"
  if [ ! -e "$file" ]; then
    echo "Нет файла: $file" >&2
    exit 1
  fi
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$file" -vn -map_metadata -1 \
    -af "loudnorm=I=-18:TP=-1.5:LRA=14" \
    -c:a aac -b:a 96k -ar 44100 -movflags +faststart "$out/$slug.m4a"
  echo "$slug: готово"
  count=$((count + 1))
done < "$here/music_tracks.txt"
echo "Готово: $count файлов в $out"
