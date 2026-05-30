CREATE EXTENSION pg_cron; -- cron - background worker process that acts like a Linux cron daemon living inside your database --
SHOW config_file;

SELECT *
FROM pg_available_extensions
WHERE name = 'pg_cron';

SELECT cron.schedule(
               'fraud-dashboard-refresh',
               '0 1 * * *', -- cron expression (Minute, Hour, Day, Month, Weekday) --
               $$CALL refresh_fraud_dashboard();$$
       );

SELECT jobid, schedule, command, nodename, nodeport, database, username -- verify it is here --
FROM cron.job;