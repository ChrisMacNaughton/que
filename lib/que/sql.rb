module Que
  SQL = {
    # Thanks to RhodiumToad in #postgresql for help with the job lock CTE.
    :lock_job => %{
      WITH RECURSIVE job AS (
        SELECT (j).*, pg_try_advisory_lock((j).job_id) AS locked
        FROM (
          SELECT j
          FROM que_jobs AS j
          WHERE run_at <= now()
          ORDER BY priority, run_at, job_id
          LIMIT 1
        ) AS t1
        UNION ALL (
          SELECT (j).*, pg_try_advisory_lock((j).job_id) AS locked
          FROM (
            SELECT (
              SELECT j
              FROM que_jobs AS j
              WHERE run_at <= now() AND (priority, run_at, job_id) > (job.priority, job.run_at, job.job_id)
              ORDER BY priority, run_at, job_id
              LIMIT 1
            ) AS j
            FROM job
            WHERE NOT job.locked
            LIMIT 1
          ) AS t1
        )
      )
      SELECT priority, run_at, job_id, job_class, args, error_count
      FROM job
      WHERE locked
      LIMIT 1
    }.freeze,

    :check_job => %{
      SELECT 1 AS one
      FROM   que_jobs
      WHERE  priority = $1::integer
      AND    run_at   = $2::timestamptz
      AND    job_id   = $3::bigint
    }.freeze,

    :set_error => %{
      UPDATE que_jobs
      SET error_count = $1::integer,
          run_at      = now() + $2::integer * '1 second'::interval,
          last_error  = $3::text
      WHERE priority  = $4::integer
      AND   run_at    = $5::timestamptz
      AND   job_id    = $6::bigint
    }.freeze,

    :insert_job => %{
      INSERT INTO que_jobs
      (priority, run_at, job_class, args)
      VALUES
      (coalesce($1, 1)::integer, coalesce($2, 'now')::timestamptz, $3::text, coalesce($4, '[]')::json)
      RETURNING *
    }.freeze,

    :destroy_job => %{
      DELETE FROM que_jobs
      WHERE priority = $1::integer
      AND   run_at   = $2::timestamptz
      AND   job_id   = $3::bigint
    }.freeze,

    :job_stats => %{
      SELECT job_class,
             count(*)                    AS count,
             count(locks.job_id)         AS count_working,
             sum((error_count > 0)::int) AS count_errored,
             max(error_count)            AS highest_error_count,
             min(run_at)                 AS oldest_run_at
      FROM que_jobs
      LEFT JOIN (
        SELECT (classid::bigint << 32) + objid::bigint AS job_id
        FROM pg_locks
        WHERE locktype = 'advisory'
      ) locks USING (job_id)
      GROUP BY job_class
      ORDER BY count(*) DESC
    }.freeze,

    :worker_states => %{
      SELECT que_jobs.*,
             pg.pid          AS pg_backend_pid,
             pg.state        AS pg_state,
             pg.state_change AS pg_state_changed_at,
             pg.query        AS pg_last_query,
             pg.query_start  AS pg_last_query_started_at,
             pg.xact_start   AS pg_transaction_started_at,
             pg.waiting      AS pg_waiting_on_lock
      FROM que_jobs
      JOIN (
        SELECT (classid::bigint << 32) + objid::bigint AS job_id, pg_stat_activity.*
        FROM pg_locks
        JOIN pg_stat_activity USING (pid)
        WHERE locktype = 'advisory'
      ) pg USING (job_id)
    }.freeze,

    :create_table => %{
      CREATE TABLE que_jobs
      (
        priority    integer     NOT NULL DEFAULT 1,
        run_at      timestamptz NOT NULL DEFAULT now(),
        job_id      bigserial   NOT NULL,
        job_class   text        NOT NULL,
        args        json        NOT NULL DEFAULT '[]'::json,
        error_count integer     NOT NULL DEFAULT 0,
        last_error  text,

        CONSTRAINT que_jobs_pkey PRIMARY KEY (priority, run_at, job_id)
      )
    }.freeze

    # Note: if schema changes to the que_jobs table become necessary later on,
    # a simple versioning scheme would be:

    # Set version:
    # COMMENT ON TABLE que_jobs IS '2'

    # Get version:
    # SELECT description
    # FROM pg_description
    # JOIN pg_class
    # ON pg_description.objoid = pg_class.oid
    # WHERE relname = 'que_jobs'
  }
end
