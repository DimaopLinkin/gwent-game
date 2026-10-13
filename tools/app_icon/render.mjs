// Растеризует SVG-слои иконки в PNG 1024×1024 (Chromium через Playwright).
//
// Нужны Node и Playwright с установленным Chromium (в репозиторий они не входят):
//   node tools/app_icon/render.mjs
// После этого tools/scripts/setup.sh разложит PNG по папкам iOS и Android.
import { chromium } from 'playwright';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const dir = path.dirname(fileURLToPath(import.meta.url));
// Слои без фона (передний план Android, монохромный) сохраняются с прозрачностью.
const layers = [
  { name: 'app_icon_ios', transparent: false },
  { name: 'app_icon_foreground', transparent: true },
  { name: 'app_icon_background', transparent: false },
  { name: 'app_icon_monochrome', transparent: true },
];

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
for (const { name, transparent } of layers) {
  await page.goto(pathToFileURL(path.join(dir, `${name}.svg`)).href);
  await page.screenshot({
    path: path.join(dir, `${name}.png`),
    omitBackground: transparent,
    clip: { x: 0, y: 0, width: 1024, height: 1024 },
  });
}
await browser.close();
