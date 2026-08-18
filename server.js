require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const crypto = require('crypto');

const app = express();
const port = process.env.PORT || 3000;
const POLL_INTERVAL_MS = 10_000;

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 5,
});

const BASE_COLUMNS = `
  p.projects_id,
  p.projects_name,
  s.projectsStatuses_name,
  p.projects_dates_use_start,
  p.projects_dates_use_end
`;

const BASE_JOIN = `
  FROM projects p
  LEFT JOIN projectsStatuses s ON s.projectsStatuses_id = p.projectsStatuses_id
`;

const EXCLUDE_MISSING_ITEMS = `AND (s.projectsStatuses_name IS NULL OR s.projectsStatuses_name <> 'Missing Items')`;
const EXCLUDE_RETURNED = `AND (s.projectsStatuses_name IS NULL OR s.projectsStatuses_name <> 'Returned')`;

const QUERIES = {
  goingOut: `
    SELECT ${BASE_COLUMNS}
    ${BASE_JOIN}
    WHERE p.projects_deleted = 0
      AND p.projects_dates_use_start BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY
      ${EXCLUDE_MISSING_ITEMS}
      ${EXCLUDE_RETURNED}
    ORDER BY p.projects_dates_use_start ASC
  `,
  currentlyOut: `
    SELECT ${BASE_COLUMNS}
    ${BASE_JOIN}
    WHERE p.projects_deleted = 0
      AND p.projects_dates_use_start <= CURDATE()
      AND p.projects_dates_use_end > CURDATE() + INTERVAL 1 DAY
      ${EXCLUDE_MISSING_ITEMS}
      ${EXCLUDE_RETURNED}
    ORDER BY p.projects_dates_use_end ASC
  `,
  comingBack: `
    SELECT ${BASE_COLUMNS}
    ${BASE_JOIN}
    WHERE p.projects_deleted = 0
      AND p.projects_dates_use_end BETWEEN CURDATE() AND CURDATE() + INTERVAL 1 DAY
      ${EXCLUDE_MISSING_ITEMS}
    ORDER BY p.projects_dates_use_end ASC
  `,
  missingItems: `
    SELECT ${BASE_COLUMNS}
    ${BASE_JOIN}
    WHERE p.projects_deleted = 0
      AND s.projectsStatuses_name = 'Missing Items'
    ORDER BY p.projects_dates_use_end DESC
  `,
};

async function fetchOrders() {
  const [[goingOut], [currentlyOut], [comingBack], [missingItems]] = await Promise.all([
    pool.query(QUERIES.goingOut),
    pool.query(QUERIES.currentlyOut),
    pool.query(QUERIES.comingBack),
    pool.query(QUERIES.missingItems),
  ]);
  return { goingOut, currentlyOut, comingBack, missingItems };
}

function hashOrders(data) {
  return crypto.createHash('sha1').update(JSON.stringify(data)).digest('hex');
}

function formatDate(value) {
  if (!value) return '—';
  const d = new Date(value);
  return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
}

const STATUS_VARIANTS = {
  booked: 'blue',
  confirmed: 'confirmed',
  'checked out': 'green',
  returned: 'tan',
  cancelled: 'white',
  'lead lost': 'white',
  'missing items': 'red',
};

function statusVariant(name) {
  const key = String(name ?? '').trim().toLowerCase();
  return STATUS_VARIANTS[key] || 'neutral';
}

function renderStatusPill(name) {
  if (!name) return '—';
  return `<span class="badge badge-status badge-status-${statusVariant(name)}">${escapeHtml(name)}</span>`;
}

function renderRows(orders, dateField, dateLabel) {
  if (orders.length === 0) {
    return '<div class="order-row order-row-empty">No orders in this window</div>';
  }
  return orders
    .map(
      (o) => `
    <div class="order-row">
      <div class="order-name">${escapeHtml(o.projects_name)}</div>
      <div class="order-meta">
        ${renderStatusPill(o.projectsStatuses_name)}
        <span class="order-date"><span class="order-date-label">${dateLabel}</span>${formatDate(o[dateField])}</span>
      </div>
    </div>`
    )
    .join('');
}

function escapeHtml(str) {
  return String(str ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[c]));
}

function renderSection({ title, subtitle, icon, orders, dateField, dateLabel, alert }) {
  return `
  <section class="glass-panel section-panel">
    <div class="section-header">
      <div class="section-icon${alert ? ' section-icon-alert' : ''}">${icon}</div>
      <div>
        <h2>${title}</h2>
        <p class="section-subtitle">${subtitle}</p>
      </div>
      <span class="badge badge-count${alert ? ' badge-count-alert' : ''}">${orders.length}</span>
    </div>
    <div class="order-list-wrap">
      <div class="order-list">
        ${renderRows(orders, dateField, dateLabel)}
      </div>
    </div>
  </section>`;
}

app.get('/', async (req, res) => {
  try {
    const { goingOut, currentlyOut, comingBack, missingItems } = await fetchOrders();

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Rentals Dashboard</title>
  <link rel="stylesheet" href="/style.css" />
</head>
<body class="theme-rentals">
  <div class="page">
    <header class="page-header">
      <h1>Rentals Dashboard</h1>
      <p class="page-subtitle">Live order logistics — read-only view of <code>projects</code></p>
    </header>
    <main class="board">
      ${renderSection({
        title: 'Going Out',
        subtitle: 'Shipping within the next 7 days',
        icon: '↗',
        orders: goingOut,
        dateField: 'projects_dates_use_start',
        dateLabel: 'Goes Out',
      })}
      ${renderSection({
        title: 'Currently Out',
        subtitle: 'Active rentals right now',
        icon: '●',
        orders: currentlyOut,
        dateField: 'projects_dates_use_end',
        dateLabel: 'Returns',
      })}
      ${renderSection({
        title: 'Coming Back',
        subtitle: 'Returning today or tomorrow',
        icon: '↙',
        orders: comingBack,
        dateField: 'projects_dates_use_end',
        dateLabel: 'Returns',
      })}
      ${renderSection({
        title: 'Missing Items',
        subtitle: 'Flagged after return, needs resolution',
        icon: '⚠',
        orders: missingItems,
        dateField: 'projects_dates_use_end',
        dateLabel: 'Returned',
        alert: true,
      })}
    </main>
    <footer class="page-footer">
      <span class="live-indicator"><span class="live-dot"></span>Live</span>
      <span>Refreshed ${new Date().toLocaleString('en-US')}</span>
    </footer>
  </div>
  <script>
    const events = new EventSource('/events');
    events.onmessage = () => location.reload();

    (function autoScrollPanels() {
      const SPEED_PX_PER_SEC = 26;
      const END_PAUSE_MS = 2600;

      const EDGE_TOLERANCE_PX = 1;

      function run(el) {
        let dir = 1;
        let paused = false;
        let last = performance.now();

        function scheduleResume(nextDir) {
          paused = true;
          dir = nextDir;
          setTimeout(() => {
            paused = false;
            last = performance.now();
          }, END_PAUSE_MS);
        }

        function tick(now) {
          const dt = now - last;
          last = now;
          const max = el.scrollHeight - el.clientHeight;

          if (!paused && max > 0) {
            const next = el.scrollTop + (dir * SPEED_PX_PER_SEC * dt) / 1000;
            el.scrollTop = Math.max(0, Math.min(max, next));

            if (dir === 1 && el.scrollTop >= max - EDGE_TOLERANCE_PX) {
              scheduleResume(-1);
            } else if (dir === -1 && el.scrollTop <= EDGE_TOLERANCE_PX) {
              scheduleResume(1);
            }
          }
          requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);
      }

      document.querySelectorAll('.order-list-wrap').forEach((el) => {
        if (el.scrollHeight > el.clientHeight + 4) run(el);
      });
    })();
  </script>
</body>
</html>`;

    res.send(html);
  } catch (err) {
    console.error(err);
    res.status(500).send(`<pre>Failed to load dashboard: ${escapeHtml(err.message)}</pre>`);
  }
});

app.get('/events', (req, res) => {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
  });
  res.write('\n');
  sseClients.add(res);
  req.on('close', () => sseClients.delete(res));
});

app.use(express.static('public'));

const sseClients = new Set();
let lastOrdersHash = null;

async function pollForChanges() {
  try {
    const hash = hashOrders(await fetchOrders());
    if (lastOrdersHash !== null && hash !== lastOrdersHash) {
      for (const client of sseClients) client.write('data: refresh\n\n');
    }
    lastOrdersHash = hash;
  } catch (err) {
    console.error('Poll for changes failed:', err.message);
  }
}

setInterval(pollForChanges, POLL_INTERVAL_MS);
pollForChanges();

app.listen(port, () => {
  console.log(`Rentals dashboard running at http://localhost:${port}`);
});
