FROM alpine:3.23
RUN apk add --no-cache bash docker-cli docker-cli-compose msmtp rclone diffutils jq
COPY msmtprc.template backup.conf.template /etc/
COPY entrypoint.sh run.sh rclone_backup.sh send_report.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/run.sh /usr/local/bin/rclone_backup.sh /usr/local/bin/send_report.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
