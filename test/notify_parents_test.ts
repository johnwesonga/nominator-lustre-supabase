import assert from "node:assert/strict";
import test from "node:test";
import {
  createNotifyParentsHandler,
  type Dependencies,
  type Email,
  type Family,
} from "../supabase/functions/notify-parents/handler.ts";

function dependencies(overrides: Partial<Dependencies> = {}): Dependencies {
  return {
    fromAddress: "Team Voting <voting@example.com>",
    voteBaseUrl: "https://nominator.example.com/vote",
    isAdmin: async () => true,
    listFamilies: async () => [],
    sendBatch: async () => true,
    ...overrides,
  };
}

function post(): Request {
  return new Request("http://localhost/functions/v1/notify-parents", {
    method: "POST",
    headers: { Authorization: "Bearer admin-jwt" },
  });
}

test("OPTIONS returns CORS preflight headers", async () => {
  const handler = createNotifyParentsHandler(dependencies());
  const response = await handler(new Request(
    "http://localhost/functions/v1/notify-parents",
    { method: "OPTIONS" },
  ));
  assert.equal(response.status, 204);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), "*");
  assert.match(response.headers.get("Access-Control-Allow-Headers") ?? "", /authorization/);
});

test("unauthorized callers cannot read families or send email", async () => {
  let listed = false;
  let sent = false;
  const handler = createNotifyParentsHandler(dependencies({
    isAdmin: async () => false,
    listFamilies: async () => { listed = true; return []; },
    sendBatch: async () => { sent = true; return true; },
  }));
  const response = await handler(post());
  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), { error: "not authorized" });
  assert.equal(listed, false);
  assert.equal(sent, false);
});

test("one email is created per family with all swimmer names", async () => {
  const families: Family[] = [{
    email: "parent@example.com",
    family_token: "family-token",
    swimmers: [{ name: "Nekesa" }, { name: "Wambui & Akinyi" }],
  }];
  const batches: Email[][] = [];
  const handler = createNotifyParentsHandler(dependencies({
    listFamilies: async () => families,
    sendBatch: async (batch) => { batches.push(batch); return true; },
  }));
  const response = await handler(post());
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { sent: 1, failed: 0 });
  assert.equal(batches.length, 1);
  assert.equal(batches[0].length, 1);
  assert.deepEqual(batches[0][0].to, ["parent@example.com"]);
  assert.match(batches[0][0].html, /Nekesa, Wambui &amp; Akinyi/);
  assert.match(batches[0][0].html, /\/vote\/family-token/);
  assert.match(batches[0][0].text, /Nekesa, Wambui & Akinyi/);
});

test("email requests are split into batches of one hundred", async () => {
  const families = Array.from({ length: 101 }, (_, index): Family => ({
    email: `parent-${index}@example.com`,
    family_token: `token-${index}`,
    swimmers: [{ name: `Swimmer ${index}` }],
  }));
  const batchSizes: number[] = [];
  const handler = createNotifyParentsHandler(dependencies({
    listFamilies: async () => families,
    sendBatch: async (batch) => { batchSizes.push(batch.length); return true; },
  }));
  const response = await handler(post());
  assert.equal(response.status, 200);
  assert.deepEqual(batchSizes, [100, 1]);
  assert.deepEqual(await response.json(), { sent: 101, failed: 0 });
});

test("database failures return a CORS-enabled 500 response", async () => {
  const handler = createNotifyParentsHandler(dependencies({
    listFamilies: async () => { throw new Error("database unavailable"); },
  }));
  const response = await handler(post());
  assert.equal(response.status, 500);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), "*");
  assert.deepEqual(await response.json(), { error: "database unavailable" });
});

test("email provider failures are counted and return a non-2xx response", async () => {
  const handler = createNotifyParentsHandler(dependencies({
    listFamilies: async () => [{
      email: "parent@example.com",
      family_token: "family-token",
      swimmers: [{ name: "Nekesa" }],
    }],
    sendBatch: async () => false,
  }));
  const response = await handler(post());
  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { sent: 0, failed: 1 });
});
