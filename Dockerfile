# ==========================================
# STAGE 1: Build ứng dụng Spring Boot
# ==========================================
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app

# Copy gradle wrapper và file cấu hình trước để tối ưu Docker layer cache
COPY gradlew .
COPY gradle ./gradle
COPY build.gradle settings.gradle ./

# Cấp quyền thực thi cho gradlew
RUN chmod +x gradlew

# Tải trước dependencies để cache
RUN ./gradlew dependencies --no-daemon || true

# Copy toàn bộ mã nguồn và build file JAR
COPY src ./src
RUN ./gradlew bootJar -x test --no-daemon

# ==========================================
# STAGE 2: Chạy ứng dụng bằng JRE siêu nhẹ
# ==========================================
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Copy file jar đã build từ Stage 1
COPY --from=build /app/build/libs/*.jar app.jar

# Cổng mặc định của Spring Boot
EXPOSE 8080

# Cấu hình biến môi trường kết nối MySQL (có thể ghi đè lúc runtime)
# Chú ý: 'mysql-db' là hostname do Docker Network tự phân giải thông qua tên container MySQL
ENV SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/productdb?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true&createDatabaseIfNotExist=true
ENV SPRING_DATASOURCE_USERNAME=root
ENV SPRING_DATASOURCE_PASSWORD=root

ENTRYPOINT ["java", "-jar", "app.jar"]
