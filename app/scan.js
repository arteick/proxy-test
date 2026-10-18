// Камера + BarcodeDetector (Chrome на Android). Без поддержки остаётся ручной ввод кода.
export const canScan = () => 'BarcodeDetector' in window && !!navigator.mediaDevices?.getUserMedia;

export async function startScan(video, onCode) {
  if (!canScan()) return () => {};
  const detector = new BarcodeDetector({ formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128'] });
  const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
  video.srcObject = stream;
  await video.play();
  let on = true;
  let last = '';
  let lastAt = 0;
  (async function loop() {
    while (on) {
      try {
        const [hit] = await detector.detect(video);
        const now = Date.now();
        if (hit && (hit.rawValue !== last || now - lastAt > 3000)) {
          last = hit.rawValue;
          lastAt = now;
          await onCode(hit.rawValue);
        }
      } catch { /* кадр не готов */ }
      await new Promise((r) => setTimeout(r, 250));
    }
  })();
  return () => { on = false; stream.getTracks().forEach((t) => t.stop()); video.srcObject = null; };
}
