const assert = require('node:assert/strict');
const express = require('express');
const { after, test } = require('node:test');
const {
  JSON_BODY_LIMIT,
  SOCIAL_POST_JSON_BODY_LIMIT,
  createJsonBodyParser,
} = require('../src/json_body_parser');

const app = express();
app.use(
  createJsonBodyParser(express, {
    standardLimit: '128b',
    socialPostLimit: '2kb',
  }),
);
app.post(['/api/social/posts', '/api/other'], (req, res) =>
  res.json({ length: req.body.content.length }),
);
app.use((error, _req, res, _next) =>
  res.status(error.status || 500).json({ error: error.message }),
);
const server = app.listen(0, '127.0.0.1');

after(() => new Promise((resolve, reject) => {
  server.close((error) => error ? reject(error) : resolve());
}));

test('social post JSON gets a larger limit than other API requests', async () => {
  const body = JSON.stringify({ content: 'x'.repeat(256) });
  const origin = `http://127.0.0.1:${server.address().port}`;
  const socialResponse = await fetch(`${origin}/api/social/posts`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body,
  });
  const otherResponse = await fetch(`${origin}/api/other`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body,
  });

  assert.equal(socialResponse.status, 200);
  assert.deepEqual(await socialResponse.json(), { length: 256 });
  for (const path of ['/api/social/posts/', '/API/SOCIAL/POSTS']) {
    const compatiblePathResponse = await fetch(`${origin}${path}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body,
    });

    assert.equal(compatiblePathResponse.status, 200, path);
    assert.deepEqual(await compatiblePathResponse.json(), { length: 256 });
  }
  assert.equal(otherResponse.status, 413);
});

test('configured JSON body limits cover base64 photo uploads only on social posts', () => {
  assert.equal(JSON_BODY_LIMIT, '20mb');
  assert.equal(SOCIAL_POST_JSON_BODY_LIMIT, '75mb');
});
