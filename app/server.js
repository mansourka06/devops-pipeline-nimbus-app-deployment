const express = require("express");
const os = require("os");
const client = require("prom-client");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;
const SERVICE_NAME = "nimbus";
const VERSION = process.env.APP_VERSION || "1.0.0";
const startTime = Date.now();

// ---- Prometheus metrics ----
const register = new client.Registry();
client.collectDefaultMetrics({ register, prefix: "nimbus_" });

const httpRequestCounter = new client.Counter({
  name: "nimbus_http_requests_total",
  help: "Total HTTP requests received",
  labelNames: ["method", "route", "status_code"],
  registers: [register],
});

const httpRequestDuration = new client.Histogram({
  name: "nimbus_http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
  registers: [register],
});

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on("finish", () => {
    const route = req.route ? req.route.path : req.path;
    httpRequestCounter.inc({ method: req.method, route, status_code: res.statusCode });
    end({ method: req.method, route, status_code: res.statusCode });
  });
  next();
});

app.use(express.static(path.join(__dirname, "public")));

// ---- Kubernetes probes ----
// Liveness: is the process alive at all.
app.get("/health", (req, res) => {
  res.status(200).json({ status: "ok" });
});

// Readiness: is the process ready to receive traffic.
// (kept simple here; a real app would check DB/cache connectivity)
app.get("/ready", (req, res) => {
  res.status(200).json({ status: "ready" });
});

// ---- App API ----
app.get("/api/info", (req, res) => {
  res.json({
    service: SERVICE_NAME,
    version: VERSION,
    hostname: os.hostname(),
    uptimeSeconds: Math.floor((Date.now() - startTime) / 1000),
    environment: process.env.NODE_ENV || "development",
  });
});

// ---- Prometheus scrape endpoint ----
app.get("/metrics", async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Nimbus listening on port ${PORT}`);
  });
}

module.exports = app;
