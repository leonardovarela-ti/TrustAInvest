-- migrations/000002_create_notifications_schema.down.sql
DROP TABLE IF EXISTS notifications.user_preferences;
DROP TABLE IF EXISTS notifications.notifications;
DROP SCHEMA IF EXISTS notifications;
