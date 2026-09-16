// Lightweight particle background (no external deps)
const canvas = document.getElementById("particles");
const ctx = canvas.getContext("2d");
let particles = [];

function resize() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
}
window.addEventListener("resize", resize);
resize();

function initParticles() {
  particles = Array.from({ length: 50 }, () => ({
    x: Math.random() * canvas.width,
    y: Math.random() * canvas.height,
    r: Math.random() * 1.8 + 0.4,
    vx: (Math.random() - 0.5) * 0.25,
    vy: (Math.random() - 0.5) * 0.25,
    a: Math.random() * 0.5 + 0.1,
  }));
}
initParticles();

function tick() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  for (const p of particles) {
    p.x += p.vx;
    p.y += p.vy;
    if (p.x < 0 || p.x > canvas.width) p.vx *= -1;
    if (p.y < 0 || p.y > canvas.height) p.vy *= -1;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(124, 92, 255, ${p.a})`;
    ctx.fill();
  }
  requestAnimationFrame(tick);
}
tick();

// Animated stat counters
document.querySelectorAll(".stat-value").forEach((el) => {
  const target = parseFloat(el.dataset.count);
  const isFloat = target % 1 !== 0;
  let current = 0;
  const step = target / 40;
  const interval = setInterval(() => {
    current += step;
    if (current >= target) {
      current = target;
      clearInterval(interval);
    }
    el.textContent = isFloat ? current.toFixed(2) : Math.round(current);
  }, 25);
});

// Pull live status from the API this same app exposes
fetch("/api/info")
  .then((r) => r.json())
  .then((data) => {
    document.getElementById("svc-name").textContent = data.service;
    document.getElementById("svc-version").textContent = data.version;
    document.getElementById("svc-host").textContent = data.hostname;
    document.getElementById("svc-uptime").textContent = `${data.uptimeSeconds}s`;
  })
  .catch(() => {
    document.getElementById("svc-name").textContent = "unavailable";
  });
