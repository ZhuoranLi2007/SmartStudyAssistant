CREATE DATABASE IF NOT EXISTS smartstudy
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- 首次部署时由管理员按实际密码创建应用账号：
-- CREATE USER 'smartstudy'@'127.0.0.1' IDENTIFIED BY 'change-this-password';
-- GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, REFERENCES
--   ON smartstudy.* TO 'smartstudy'@'127.0.0.1';
-- FLUSH PRIVILEGES;
--
-- 随后配置 server/.env 并执行：
-- .\.venv\Scripts\python.exe -m alembic upgrade head
