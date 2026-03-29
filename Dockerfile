FROM haproxy:3.2-alpine

USER root

COPY ./haproxy/haproxy.cfg /app/haproxy.cfg
COPY ./haproxy/lua/ /etc/haproxy/lua/
COPY docker-entrypoint.sh /app/docker-entrypoint.sh

RUN mkdir -p /etc/haproxy /etc/haproxy/data /var/run/haproxy /app && \
    cp /app/haproxy.cfg /etc/haproxy/haproxy.cfg && \
    chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/etc/haproxy/haproxy.cfg", "-db"]
