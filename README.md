# Rentals Dashboard

Local, read-only dashboard over the Rainscope Rentals `projects` table. Shows three sections:

- **Going Out** — orders shipping in the next 7 days (`projects_dates_use_start`)
- **Currently Out** — orders active right now
- **Coming Back** — orders returning in the next 7 days (`projects_dates_use_end`)

Styled with the [Rainscope Design System](https://github.com/Rainscopefilmworks/rainscope-design-system) Rentals lane (onyx + ocean blue). Token CSS is copied into `public/tokens/`.

## Setup

1. Install dependencies:

   ```bash
   npm install
   ```

2. Fill in `.env` with your DB connection details:

   ```
   DB_HOST=
   DB_PORT=3306
   DB_USER=
   DB_PASSWORD=
   DB_NAME=
   PORT=3000
   ```

   Use a MySQL user with **SELECT-only** grants — this app never writes to the database, but it's good practice to enforce that at the DB level too.

3. Start the server:

   ```bash
   npm start
   ```

4. Open [http://localhost:3000](http://localhost:3000).
