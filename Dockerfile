# Update ubuntu image and awscli after docker is upgraded to 20.10.10+
# https://medium.com/nttlabs/ubuntu-21-10-and-fedora-35-do-not-work-on-docker-20-10-9-1cd439d9921
FROM ubuntu:18.04

# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html
# https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst
ENV AWSCLI_VERSION=2.0.2

RUN apt-get update && \
  apt-get install -y curl unzip pigz mysql-client && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  curl -sSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip -o /tmp/awscliv2.zip && \
  unzip -q /tmp/awscliv2.zip -d /tmp && \
  /tmp/aws/install && \
  rm -rf /tmp/aws /tmp/awscliv2.zip

COPY mysqldump-backup.sh /
COPY backup.sh /

CMD ["/backup.sh"]
