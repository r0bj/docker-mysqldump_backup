FROM alpine:3.9

RUN apk add --no-cache bash curl mariadb-client py3-pip pigz && pip3 install s3cmd

COPY mysqldump-backup.sh /
COPY backup.sh /

CMD [ "/backup.sh" ]
