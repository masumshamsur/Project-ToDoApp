-- Schema for the To-Do app. Column names match the queries in index.js.
CREATE DATABASE IF NOT EXISTS todo_app;
USE todo_app;

CREATE TABLE IF NOT EXISTS Tasks (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  task_name        VARCHAR(255) NOT NULL,
  task_description TEXT,
  due_date         DATE,
  completed        TINYINT(1) NOT NULL DEFAULT 0,
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
