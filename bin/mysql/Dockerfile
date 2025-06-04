FROM mysql:8.0

COPY custom.cnf /etc/mysql/conf.d/custom.cnf
# Fix permissions AND ownership - both are required
RUN chmod 644 /etc/mysql/conf.d/custom.cnf && \
    chown mysql:mysql /etc/mysql/conf.d/custom.cnf