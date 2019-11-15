FROM grafana/grafana:6.4.4
USER root
RUN apk add curl && \
      curl -L https://github.com/telia-oss/aws-env/releases/download/v0.3.0/aws-env-linux-amd64 > /usr/local/bin/aws-env && \
      chmod +x /usr/local/bin/aws-env

COPY entrypoint.sh ./
USER grafana
ENTRYPOINT ["./entrypoint.sh"]