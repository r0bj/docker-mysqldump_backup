FROM alpine:3.9

ENV S3CMD_VERSION 2.0.2

RUN apk add --no-cache bash curl mariadb-client pigz python3
RUN wget https://github.com/s3tools/s3cmd/releases/download/v${S3CMD_VERSION}/s3cmd-${S3CMD_VERSION}.tar.gz \
  && tar xvpzf s3cmd-${S3CMD_VERSION}.tar.gz \
  && rm -f s3cmd-${S3CMD_VERSION}.tar.gz \
  && cd s3cmd-${S3CMD_VERSION} \
  && python3 setup.py install \
  && cd .. \
  && rm -rf s3cmd-${S3CMD_VERSION}

COPY mysqldump-backup.sh /
COPY backup.sh /

CMD [ "/backup.sh" ]
