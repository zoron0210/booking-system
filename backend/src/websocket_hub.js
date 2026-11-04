const { WebSocket, WebSocketServer } = require('ws');

function createWebSocketHub({
  jwt,
  pool,
  secret,
  allowedOrigins = [],
  environment = process.env.NODE_ENV,
}) {
  const clientsByUser = new Map();
  const allowedOriginSet = new Set(allowedOrigins);
  const webSocketServer = new WebSocketServer({
    noServer: true,
    maxPayload: 4096,
    perMessageDeflate: false,
  });
  let heartbeat;

  function rejectUpgrade(socket, status = 403) {
    socket.write(
      `HTTP/1.1 ${status} ${status === 403 ? 'Forbidden' : 'Not Found'}\r\n` +
        'Connection: close\r\n\r\n',
    );
    socket.destroy();
  }

  function removeClient(userId, socket) {
    if (!userId) return;
    const userClients = clientsByUser.get(userId);
    if (!userClients) return;
    userClients.delete(socket);
    if (userClients.size === 0) clientsByUser.delete(userId);
  }

  function attach(server) {
    server.on('upgrade', (request, socket, head) => {
      let pathname;
      try {
        pathname = new URL(request.url, 'http://localhost').pathname;
      } catch {
        rejectUpgrade(socket, 404);
        return;
      }
      if (pathname !== '/api/live') {
        rejectUpgrade(socket, 404);
        return;
      }

      const origin = request.headers.origin;
      if (
        origin &&
        ((environment === 'production' && !allowedOriginSet.has(origin)) ||
          (allowedOriginSet.size > 0 && !allowedOriginSet.has(origin)))
      ) {
        rejectUpgrade(socket);
        return;
      }
      webSocketServer.handleUpgrade(request, socket, head, (client) => {
        webSocketServer.emit('connection', client, request);
      });
    });

    heartbeat = setInterval(() => {
      for (const client of webSocketServer.clients) {
        if (client.isAlive === false) {
          client.terminate();
          continue;
        }
        client.isAlive = false;
        client.ping();
      }
    }, 30_000);
    heartbeat.unref();
    server.once('close', () => {
      clearInterval(heartbeat);
      webSocketServer.close();
    });
  }

  webSocketServer.on('connection', (client) => {
    let userId;
    let authenticating = false;
    let authenticated = false;
    let authenticationTimeout = setTimeout(() => {
      client.close(4401, 'Authentication required');
    }, 5_000);
    authenticationTimeout.unref();
    client.isAlive = true;
    client.on('pong', () => {
      client.isAlive = true;
    });
    client.on('error', (error) => {
      console.error('Live update socket failed.', error);
    });
    client.on('close', () => {
      clearTimeout(authenticationTimeout);
      removeClient(userId, client);
    });
    client.on('message', (data, isBinary) => {
      if (authenticated || authenticating || isBinary) return;
      authenticating = true;
      void authenticate(data.toString())
        .then((authenticatedUser) => {
          if (!authenticatedUser || client.readyState !== WebSocket.OPEN) return;
          userId = authenticatedUser.id;
          authenticated = true;
          clearTimeout(authenticationTimeout);
          let userClients = clientsByUser.get(userId);
          if (!userClients) {
            userClients = new Set();
            clientsByUser.set(userId, userClients);
          }
          userClients.add(client);
          client.send(JSON.stringify({ type: 'ready' }));
          const expiresInMs = authenticatedUser.expiresAt - Date.now();
          const expirationTimeout = setTimeout(() => {
            client.close(4401, 'Access token expired');
          }, expiresInMs);
          expirationTimeout.unref();
          client.once('close', () => clearTimeout(expirationTimeout));
        })
        .catch(() => {
          if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({ type: 'error' }));
            client.close(4401, 'Authentication failed');
          }
        });
    });
  });

  async function authenticate(data) {
    let message;
    try {
      message = JSON.parse(data);
    } catch {
      throw new Error('Invalid authentication message.');
    }
    if (
      !message ||
      message.type !== 'authenticate' ||
      typeof message.token !== 'string' ||
      message.token.length > 8192
    ) {
      throw new Error('Invalid authentication message.');
    }

    const payload = jwt.verify(message.token, secret);
    if (
      !payload ||
      typeof payload !== 'object' ||
      !/^\d+$/.test(String(payload.sub)) ||
      !Number.isInteger(Number(payload.exp))
    ) {
      throw new Error('Invalid access token.');
    }
    const expiresAt = Number(payload.exp) * 1000;
    if (expiresAt <= Date.now()) throw new Error('Access token expired.');

    const [rows] = await pool.execute(
      'SELECT status FROM users WHERE id = ? LIMIT 1',
      [String(payload.sub)],
    );
    if (rows[0]?.status !== 'active') throw new Error('Account is not active.');
    return { id: String(payload.sub), expiresAt };
  }

  function publishToUser(userId, event) {
    const userClients = clientsByUser.get(String(userId));
    if (!userClients) return;
    const data = JSON.stringify(event);
    for (const client of userClients) {
      if (client.readyState !== WebSocket.OPEN) continue;
      try {
        client.send(data);
      } catch (error) {
        console.error('Could not send a live update.', error);
        client.terminate();
      }
    }
  }

  function closeUser(userId) {
    const userClients = clientsByUser.get(String(userId));
    if (!userClients) return;
    for (const client of userClients) {
      client.close(4403, 'Account status changed');
    }
  }

  return { attach, closeUser, publishToUser };
}

module.exports = { createWebSocketHub };
