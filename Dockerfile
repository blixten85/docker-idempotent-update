FROM alpine:3.21
RUN apk add --no-cache bash docker-cli docker-cli-compose msmtp rclone diffutils
COPY msmtprc.template backup.conf.template /etc/
COPY entrypoint.sh run.sh rclone_backup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/run.sh /usr/local/bin/rclone_backup.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
