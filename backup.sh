#!/bin/bash

prometheus_pushgateway_url=${PUSHGATEWAY_URL:-http://127.0.0.1:9091}
prometheus_job=${PROMETHEUS_JOB:-mysqldump-backup}

function write_log {
	echo "`date +'%Y%m%d %H%M%S'`: $1"
}

function notify_prometheus {
	local success="$1"
	local duration="$2"
	if [ -n "$prometheus_pushgateway_url" ] && [ -n "$prometheus_job" ]; then
		if [ "$success" -eq 1 ]; then
			write_log "INFO: notify prometheus: backup success; duration: $duration"
cat <<EOF | curl -s -XPOST --data-binary @- ${prometheus_pushgateway_url}/metrics/job/${prometheus_job}/instance/$hostname
# HELP mysqldump_backup_duration_seconds Duration of mysqldump backup
# TYPE mysqldump_backup_duration_seconds gauge
mysqldump_backup_duration_seconds $duration
# HELP mysqldump_backup_last_success_timestamp_seconds Unixtime mysqldump backup last succeeded
# TYPE mysqldump_backup_last_success_timestamp_seconds gauge
mysqldump_backup_last_success_timestamp_seconds $(date +%s.%7N)
# HELP mysqldump_backup_last_success Success of mysqldump backup
# TYPE mysqldump_backup_last_success gauge
mysqldump_backup_last_success 1
EOF
		else
			write_log "INFO: notify prometheus: backup failed"
cat <<EOF | curl -s -XPOST --data-binary @- ${prometheus_pushgateway_url}/metrics/job/${prometheus_job}/instance/$hostname
# HELP mysqldump_backup_last_success Success of mysqldump backup
# TYPE mysqldump_backup_last_success gauge
mysqldump_backup_last_success 0
EOF
		fi
	fi
}

hostname=$(hostname)
start_timastamp=$(date +'%s')

bash /mysqldump-backup.sh
if [ "$?" -eq 0 ]; then
	duration=$(($(date +'%s') - $start_timastamp))
	notify_prometheus 1 $duration
else
	notify_prometheus 0
fi
