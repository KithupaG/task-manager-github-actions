require('dotenv').config();
const Pool = require("pg").Pool;

const pool = new Pool({
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    host: process.env.DB_HOST || "localhost",
    port: 5432,
    database: process.env.DB_NAME || "perntodo"
});

const connectWithRetry = async () => {
    let attempts = 5;
    while (attempts) {
        try {
            await pool.query('SELECT 1');
            console.log("Database connected successfully.");
            break;
        } catch (err) {
            console.error(`Connection failed. Retries left: ${attempts - 1}`);
            attempts -= 1;
            await new Promise(res => setTimeout(res, 2000));
        }
    }
};
connectWithRetry();
module.exports = pool;
