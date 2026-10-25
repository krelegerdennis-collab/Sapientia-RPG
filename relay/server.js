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
