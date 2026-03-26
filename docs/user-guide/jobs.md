# Jobs & CronJobs

## Job List

The jobs page shows all Kubernetes Jobs with:
- **Name** — Links to job detail
- **Status** — Health badge (healthy = succeeded, error = failed, warning = active)
- **Active/Succeeded/Failed** — Execution counts
- **Duration** — Time from start to completion
- **Started** — Job start timestamp

## Job Detail

### Stats
Four cards showing Active, Succeeded, Failed counts, and Duration.

### Run History Timeline
A Jenkins-style visual timeline showing recent job runs:
- **Green bars** — Succeeded runs
- **Red bars** — Failed runs
- **Yellow bars** — Active or unknown runs
- Bar height represents relative duration
- Hover over a bar to see job name, status, and duration

This timeline is populated from PostgreSQL history, so it persists across pod restarts.

### Pods
Lists the pods created by this job, with their status and logs accessible.

### Events
Job-specific Kubernetes events.

## CronJob List

The CronJobs page shows:
- **Schedule** — Cron expression
- **Suspended** — Whether the CronJob is paused
- **Active** — Number of currently running jobs
- **Last Schedule** — When the last job was created
- **Last Success** — When the last job succeeded

## Identifying Issues

Common patterns to watch for:
- Jobs with high Failed counts — check pod logs for errors
- CronJobs with no recent Last Success — may be silently failing
- Long-running active jobs — may be stuck
- CronJobs in Suspended state — may have been paused accidentally
