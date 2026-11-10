'use strict';
const { createRelay } = require('./src/relay');
const { configFromEnv } = require('./src/config');

const cfg = configFromEnv();
for (const arg of process.argv.slice(2)) {
  const m = /^--port=(\d+)$/.exec(arg);
  if (m) cfg.port = Number.parseInt(m[1], 10);
  else if (arg === '--quiet') cfg.quiet = true;
}

const relay = createRelay(cfg);
relay
  .listen()
  .then((addr) => {
    // De Godot-test wacht op deze regel.
    process.stdout.write(`LISTENING port=${addr.port}\n`);
  })
  .catch((err) => {
    process.stderr.write(`relay: kan niet starten: ${err.message}\n`);
    process.exit(1);
  });

function shutdown() {
  relay.close().then(() => process.exit(0));
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

function logCrash(kind, err) {
  const line = JSON.stringify({
    ts: new Date().toISOString(),
    event: kind,
    err: err && err.message ? err.message : String(err),
  });
  process.stderr.write(`${line}\n`);
}

process.on('uncaughtException', (err) => {
  logCrash('uncaughtException', err);
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logCrash('unhandledRejection', reason instanceof Error ? reason : new Error(String(reason)));
});
