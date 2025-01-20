#!/bin/bash

prometheus_pushgateway_url=${PUSHGATEWAY_URL}
prometheus_job=${PROMETHEUS_JOB:-mysqldump-backup}
override_hostname=${OVERRIDE_HOSTNAME}
auth_user=${BASIC_AUTH_USER}
auth_password=${BASIC_AUTH_PASSWORD}

function log {
	echo "`date +'%Y%m%d %H%M%S'`: $1"
}

function push_status_metric {
	local success="$1"
	local duration="$2"

	if [[ -n "$auth_user" && -n "$auth_password" ]]; then
		curl_opts="-u ${auth_user}:$auth_password"
	fi

	if [[ -z "$prometheus_pushgateway_url" || -z "$prometheus_job" ]]; then
		log "Notifying prometheus failed, missing parameters"
		return 1
	fi

	if [[ "$success" -eq 1 ]]; then
		log "Notifying prometheus: backup success; duration: ${duration}s"
cat <<EOF | curl -o /dev/null -s -w "URL: %{url_effective}\nRemote IP: %{remote_ip}\nHTTP Code: %{http_code}\n" --max-time 60 $curl_opts -XPOST --data-binary @- ${prometheus_pushgateway_url}/metrics/job/${prometheus_job}/instance/$hostname
# HELP mysqldump_backup_duration_seconds Duration of mysqldump backup
# TYPE mysqldump_backup_duration_seconds gauge
mysqldump_backup_duration_seconds $duration
# HELP mysqldump_backup_last_success_timestamp_seconds Unixtime mysqldump backup last succeeded
# TYPE mysqldump_backup_last_success_timestamp_seconds gauge
mysqldump_backup_last_success_timestamp_seconds $(date +%s.%7N)
# HELP mysqldump_backup_status Status of mysqldump backup
# TYPE mysqldump_backup_status gauge
mysqldump_backup_status 1
EOF
	else
		log "Notifying prometheus: backup failed"
cat <<EOF | curl -o /dev/null -s -w "URL: %{url_effective}\nRemote IP: %{remote_ip}\nHTTP Code: %{http_code}\n" --max-time 60 $curl_opts -XPOST --data-binary @- ${prometheus_pushgateway_url}/metrics/job/${prometheus_job}/instance/$hostname
# HELP mysqldump_backup_status Status of mysqldump backup
# TYPE mysqldump_backup_status gauge
mysqldump_backup_status 0
EOF
	fi
}

function push_state_metric {
	local running="$1"

	if [[ -n "$auth_user" && -n "$auth_password" ]]; then
		curl_opts="-u ${auth_user}:$auth_password"
	fi

	if [[ -z "$prometheus_pushgateway_url" || -z "$prometheus_job" ]]; then
		log "Notifying prometheus failed, missing parameters"
		return 1
	fi

	if [[ "$running" -eq 1 ]]; then
		log "Notifying prometheus: backup is in progress"
cat <<EOF | curl -o /dev/null -s -w "URL: %{url_effective}\nRemote IP: %{remote_ip}\nHTTP Code: %{http_code}\n" --max-time 60 $curl_opts -XPOST --data-binary @- ${prometheus_pushgateway_url}/metrics/job/${prometheus_job}/instance/$hostname
# HELP mysqldump_backup_running Mysqldump backup is in progress
# TYPE mysqldump_backup_running gauge
mysqldump_backup_running 1
EOF
	else
		log "Notifying prometheus: backup is not running"
cat <<EOF | curl -o /dev/null -s -w "URL: %{url_effective}\nRemote IP: %{remote_ip}\nHTTP Code: %{http_code}\n" --max-time 60 $curl_opts -XPOST --data-binary @- ${prometheus_pushgateway_url}/metrics/job/${prometheus_job}/instance/$hostname
# HELP mysqldump_backup_running Mysqldump backup is in progress
# TYPE mysqldump_backup_running gauge
mysqldump_backup_running 0
EOF
	fi
}

function cleanup {
    log "Received termination signal. Running cleanup..."
    push_state_metric 0
    push_status_metric 0
    exit 1
}

# Trap signals and call cleanup on SIGINT and SIGTERM
trap cleanup SIGINT SIGTERM

if [[ -n "$override_hostname" ]]; then
	hostname=$override_hostname
else
	hostname=$(hostname)
fi

start_timastamp=$(date +'%s')

push_state_metric 1
bash /mysqldump-backup.sh
push_state_metric 0
if [[ "$?" -eq 0 ]]; then
	duration=$(($(date +'%s') - $start_timastamp))
	push_status_metric 1 $duration
	exit 0
else
	push_status_metric 0
	exit 1
fi
