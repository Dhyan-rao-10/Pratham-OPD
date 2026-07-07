const { Pool } = require('pg');

let config;

// Railway / Heroku style DATABASE_URL takes precedence
if (process.env.DATABASE_URL) {
  config = {
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('railway') || process.env.DATABASE_URL.includes('.proxy.') || process.env.NODE_ENV === 'production'
      ? { rejectUnauthorized: false }
      : false,
  };
} else {
  config = {
    host: process.env.POSTGRES_HOST || 'localhost',
    port: parseInt(process.env.POSTGRES_PORT || '5432'),
    database: process.env.POSTGRES_DB || 'opd_preconsult',
    user: process.env.POSTGRES_USER || 'opd_user',
    password: process.env.POSTGRES_PASSWORD || 'changeme_in_production',
  };
}

console.log('[db] Connecting to:', config.connectionString ? 'DATABASE_URL' : `${config.host}:${config.port}/${config.database}`);

const pool = new Pool(config);

module.exports = pool;
