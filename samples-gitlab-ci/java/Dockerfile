FROM eclipse-temurin:17-jre-noble@sha256:b3e1d0486f09293b2455aed02d396d4b6b5ea9b0e8c7c065c297cfef453b0116
WORKDIR /app
COPY --chown=10001:10001 dist/application.jar /app/application.jar
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/application.jar"]
