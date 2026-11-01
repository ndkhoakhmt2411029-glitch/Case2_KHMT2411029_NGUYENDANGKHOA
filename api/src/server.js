require('dotenv').config();

const app = require('./app');
const connectDatabase = require('./config/database');

const PORT = process.env.PORT || 3000;

async function start() {
  if (!process.env.JWT_SECRET) {
    throw new Error('Thiếu biến môi trường JWT_SECRET');
  }
  await connectDatabase();
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`API chạy tại http://localhost:${PORT}/api`);
  });
}

start().catch((err) => {
  console.error('Không thể khởi động server:', err.message);
  process.exit(1);
});
