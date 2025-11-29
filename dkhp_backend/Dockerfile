FROM eclipse-temurin:17-jdk-alpine

# Set directory
WORKDIR /app

# Copy war file
COPY target/demo-0.0.1-SNAPSHOT.war dkhp_backend.war

# Create non-root user
RUN adduser -D dkhp_backend
RUN chown -R dkhp_backend. /app
USER dkhp_backend

# Endtrypoint
ENTRYPOINT ["java","--add-opens", "java.base/java.io=ALL-UNNAMED", "-jar","dkhp_backend.war"]

# Expose port 8080
EXPOSE 8080
