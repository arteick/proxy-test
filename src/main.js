import * as THREE from 'three';
import { RAMP } from './ascii.js';

const CELL = 10; // размер ячейки символа в пикселях
const NEAR = 0.1, FAR = 60;

const renderer = new THREE.WebGLRenderer({ antialias: false });
renderer.setPixelRatio(1);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x070910);
const camera = new THREE.PerspectiveCamera(50, 1, NEAR, FAR);

// --- мир ---
const ground = new THREE.Mesh(
  new THREE.PlaneGeometry(200, 200),
  new THREE.MeshStandardMaterial({ color: 0x3c424e, roughness: 0.9 })
);
ground.rotation.x = -Math.PI / 2;
ground.receiveShadow = true;
scene.add(ground);

const stone = new THREE.MeshStandardMaterial({ color: 0xa8aab3, roughness: 0.8 });
for (let i = 0; i < 14; i++) {
  const h = 2 + (i % 4) * 1.2;
  const p = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.6, h, 10), stone);
  const side = i % 2 ? 1 : -1;
  p.position.set(side * 4.5, h / 2, -i * 4.5);
  p.castShadow = p.receiveShadow = true;
  scene.add(p);
}

// --- персонаж ---
const hero = new THREE.Group();
const skin = new THREE.MeshStandardMaterial({ color: 0xe8c9a0, roughness: 0.7 });
const cloth = new THREE.MeshStandardMaterial({ color: 0x3d7bd9, roughness: 0.6 });
const dark = new THREE.MeshStandardMaterial({ color: 0x35394a, roughness: 0.7 });
const part = (geo, mat, x, y, z) => {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  m.castShadow = true;
  return m;
};
const body = part(new THREE.CapsuleGeometry(0.38, 0.7, 6, 12), cloth, 0, 1.35, 0);
const head = part(new THREE.SphereGeometry(0.32, 20, 16), skin, 0, 2.15, 0);
const hat = part(new THREE.ConeGeometry(0.36, 0.5, 16), dark, 0, 2.6, 0);
const limb = (mat, x, y, len) => {
  const pivot = new THREE.Group();
  pivot.position.set(x, y, 0);
  const m = new THREE.Mesh(new THREE.CapsuleGeometry(0.11, len, 4, 8), mat);
  m.position.y = -len / 2 - 0.1;
  m.castShadow = true;
  pivot.add(m);
  return pivot;
};
const armL = limb(skin, -0.5, 1.75, 0.6), armR = limb(skin, 0.5, 1.75, 0.6);
const legL = limb(dark, -0.2, 0.9, 0.6), legR = limb(dark, 0.2, 0.9, 0.6);
hero.add(body, head, hat, armL, armR, legL, legR);
scene.add(hero);

// --- свет ---
scene.add(new THREE.HemisphereLight(0x7080b8, 0x2a2018, 0.9));
const key = new THREE.PointLight(0xffc680, 150, 40, 1.4);
key.castShadow = true;
key.shadow.mapSize.set(1024, 1024);
key.position.set(2, 3, 2);
scene.add(key);
const rim = new THREE.PointLight(0x5aa0ff, 70, 30, 1.4);
rim.position.set(-3, 2.5, -5);
scene.add(rim);

// --- ASCII-постобработка ---
const atlasCanvas = document.createElement('canvas');
const G = 32;
atlasCanvas.width = G * RAMP.length;
atlasCanvas.height = G;
{
  const c = atlasCanvas.getContext('2d');
  c.fillStyle = '#000';
  c.fillRect(0, 0, atlasCanvas.width, G);
  c.fillStyle = '#fff';
  c.font = `bold ${G * 0.9}px "DejaVu Sans Mono", Menlo, Consolas, monospace`;
  c.textAlign = 'center';
  c.textBaseline = 'middle';
  [...RAMP].forEach((ch, i) => c.fillText(ch, i * G + G / 2, G / 2 + 1));
}
const atlas = new THREE.CanvasTexture(atlasCanvas);
atlas.minFilter = atlas.magFilter = THREE.LinearFilter;

let target;
const quadMat = new THREE.ShaderMaterial({
  uniforms: {
    tColor: { value: null }, tDepth: { value: null }, tAtlas: { value: atlas },
    uRes: { value: new THREE.Vector2() }, uCell: { value: CELL },
    uN: { value: RAMP.length }, uNear: { value: NEAR }, uFar: { value: FAR },
    uFadeNear: { value: 10 }, uFadeFar: { value: 36 },
  },
  vertexShader: `varying vec2 vUv; void main(){ vUv=uv; gl_Position=vec4(position.xy,0.,1.); }`,
  fragmentShader: `
    uniform sampler2D tColor, tDepth, tAtlas;
    uniform vec2 uRes; uniform float uCell, uN, uNear, uFar, uFadeNear, uFadeFar;
    varying vec2 vUv;
    float lin(float d){ float z=d*2.-1.; return 2.*uNear*uFar/(uFar+uNear-z*(uFar-uNear)); }
    void main(){
      vec2 px = vUv*uRes;
      vec2 cell = floor(px/uCell);
      vec2 local = fract(px/uCell);
      vec2 cuv = (cell+.5)*uCell/uRes;
      vec3 col = texture2D(tColor,cuv).rgb;
      float dist = lin(texture2D(tDepth,cuv).x);
      float lum = dot(col, vec3(.299,.587,.114));
      lum = pow(clamp(lum*1.2,0.,1.), .8);
      float idx = floor(lum*(uN-1.)+.5);
      float cov = texture2D(tAtlas, vec2((idx+local.x)/uN, 1.-local.y)).r;
      float fade = smoothstep(uFadeNear,uFadeFar,dist);
      // вдали символ растворяется в сплошной цвет той же яркости
      float solid = mix(.05, .55, lum);
      float v = mix(cov, solid, fade);
      vec3 tint = col/max(lum,.04);
      tint = mix(vec3(1.), tint, .85);
      vec3 outc = tint*v*(.35+1.1*lum) + col*.10;
      // виньетка
      vec2 q = vUv-.5; outc *= 1.-dot(q,q)*.9;
      gl_FragColor = vec4(pow(outc, vec3(.95)),1.);
    }`,
  depthTest: false, depthWrite: false,
});
const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), quadMat);
quad.frustumCulled = false;
const post = new THREE.Scene();
post.add(quad);
const postCam = new THREE.Camera();

function resize() {
  const w = innerWidth, h = innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  target?.dispose();
  target = new THREE.WebGLRenderTarget(w, h);
  target.depthTexture = new THREE.DepthTexture(w, h);
  quadMat.uniforms.tColor.value = target.texture;
  quadMat.uniforms.tDepth.value = target.depthTexture;
  quadMat.uniforms.uRes.value.set(w, h);
}
addEventListener('resize', resize);
resize();

// --- управление ---
let mx = 0.6, my = 0.4, zoom = 1;
addEventListener('pointermove', e => { mx = e.clientX / innerWidth; my = e.clientY / innerHeight; });
addEventListener('wheel', e => { zoom = Math.min(2.2, Math.max(0.5, zoom * (e.deltaY > 0 ? 1.06 : 0.94))); });

const clock = new THREE.Clock();
function frame() {
  const t = clock.getElapsedTime();
  const swing = Math.sin(t * 3) * 0.6;
  armL.rotation.x = swing; armR.rotation.x = -swing;
  legL.rotation.x = -swing; legR.rotation.x = swing;
  hero.position.y = Math.abs(Math.sin(t * 3)) * 0.06;
  hero.rotation.y = Math.sin(t * 0.4) * 0.5;
  key.position.set((mx - 0.5) * 12, 1.2 + (1 - my) * 5, 2 + Math.sin(t * 0.7));
  camera.position.set(0, 2.0 * zoom, 4.6 * zoom);
  camera.lookAt(0, 1.5, -3);
  renderer.setRenderTarget(target);
  renderer.render(scene, camera);
  renderer.setRenderTarget(null);
  renderer.render(post, postCam);
  requestAnimationFrame(frame);
}
frame();
