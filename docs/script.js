const scenes = {
  day: ['Sunlit garden with flowering plants', 'A little sunlight, wherever you work.'],
  night: ['Moonlit garden with sleeping bees and butterflies', 'A quieter world after dark.'],
  winter: ['Snow-covered garden with accumulation on flowers and ground', 'Winter settles in. Warmth will return.'],
  controls: ['Stillgarden with planting and growth controls visible', 'Your garden, at your pace.']
};
const image = document.querySelector('#gallery-image');
const caption = document.querySelector('#scene-caption');
document.querySelectorAll('[data-scene]').forEach(button => {
  button.addEventListener('click', () => {
    const scene = button.dataset.scene;
    if (!scenes[scene]) return;
    document.querySelectorAll('[data-scene]').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
    image.src = `assets/${scene}.png`;
    image.alt = scenes[scene][0];
    caption.textContent = scenes[scene][1];
  });
});
