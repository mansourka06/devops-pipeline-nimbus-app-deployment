const request = require("supertest");
const app = require("../server");

describe("Nimbus API", () => {
  test("GET /health returns 200 and status ok", async () => {
    const res = await request(app).get("/health");
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ status: "ok" });
  });

  test("GET /ready returns 200 and status ready", async () => {
    const res = await request(app).get("/ready");
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ status: "ready" });
  });

  test("GET /api/info returns service metadata", async () => {
    const res = await request(app).get("/api/info");
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty("service", "nimbus");
    expect(res.body).toHaveProperty("version");
    expect(res.body).toHaveProperty("hostname");
    expect(res.body).toHaveProperty("uptimeSeconds");
  });

  test("GET /metrics exposes Prometheus format", async () => {
    const res = await request(app).get("/metrics");
    expect(res.statusCode).toBe(200);
    expect(res.text).toContain("nimbus_http_requests_total");
  });

  test("GET / serves the landing page", async () => {
    const res = await request(app).get("/");
    expect(res.statusCode).toBe(200);
    expect(res.text).toContain("Nimbus");
  });

  test("unknown route returns 404", async () => {
    const res = await request(app).get("/does-not-exist");
    expect(res.statusCode).toBe(404);
  });
});
