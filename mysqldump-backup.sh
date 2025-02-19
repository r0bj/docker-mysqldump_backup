#!/bin/bash

set -eo pipefail

mysql_user=${MYSQL_USER:-root}
mysql_password=${MYSQL_PASSWORD}
mysql_host=${MYSQL_HOST:-127.0.0.1}
s3_bucket=${S3_BUCKET}
s3_access_key=${S3_ACCESS_KEY}
s3_secret_key=${S3_SECRET_KEY}
override_hostname=${OVERRIDE_HOSTNAME}
databases_parameter="--databases"

if [[ "$OMIT_DATABASES_PARAMETER" == "true" ]]; then
  databases_parameter=""
fi

function log {
	echo "`date +'%Y%m%d %H%M%S'`: $1"
}

if [[ -z "$mysql_password" || -z "$s3_bucket" || -z "$s3_access_key" || -z "$s3_secret_key" ]]; then
	log "One or more parameter empty"
	exit 1
fi

export MYSQL_PWD=$mysql_password

databases=$(mysql --host=$mysql_host --user=$mysql_user -sse "SHOW DATABASES;" | grep -vE "^(information_schema|performance_schema|sys)$")
date=$(date +'%Y%m%d')

if [[ -n "$override_hostname" ]]; then
	hostname=$override_hostname
else
	hostname=$(hostname)
fi

log "Dumping databases: $(echo $databases | tr '\n' ' ')"

export AWS_ACCESS_KEY_ID=$s3_access_key
export AWS_SECRET_ACCESS_KEY=$s3_secret_key
export AWS_RETRY_MODE=standard
export AWS_MAX_ATTEMPTS=6

for db in $databases; do
	timestamp=$(date +'%Y%m%d_%H%M%S')
	filename="${db}-${timestamp}.sql.gz"
	tmpfile="/tmp/$filename"
	object="s3://${s3_bucket}/${hostname}/${date}/${filename}"

	log "Dumping database $db"
	mysqldump --host=$mysql_host --user=$mysql_user --single-transaction --set-gtid-purged=OFF $databases_parameter $db | pigz > $tmpfile
	log "Dumping database $db done"

	log "Uploading file $tmpfile to $object"
	aws s3 cp $tmpfile $object --no-progress
	log "Uploading file $tmpfile done"

	rm -f $tmpfile
done
