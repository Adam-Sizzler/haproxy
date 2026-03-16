FROM haproxy:3.2-alpine

USER root

COPY ./haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg
COPY ./haproxy/lua/ /etc/haproxy/lua/
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chown haproxy:haproxy /etc/haproxy/haproxy.cfg

USER haproxy

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["haproxy"]
