# ========================================================
# Stage 1: Build Image MySQL chứa sẵn dữ liệu mẫu (Mock data)
# Lệnh build: docker build --target mysql-db -t my-mysql-image .
# ========================================================
FROM mysql:8.0 AS mysql-db
ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=productdb
# Copy file SQL vào thư mục init của MySQL, MySQL sẽ tự động chạy script này khi container khởi tạo
COPY src/main/resources/db/init.sql /docker-entrypoint-initdb.d/

# ========================================================
# Stage 2: Build file JAR ứng dụng Spring Boot bằng Gradle
# ========================================================
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app

# Copy wrapper và file cấu hình trước để tận dụng Docker layer cache
COPY gradlew .
COPY gradle ./gradle
COPY build.gradle settings.gradle ./

# Cấp quyền thực thi cho gradlew
RUN chmod +x gradlew

# Tải trước dependencies
RUN ./gradlew dependencies --no-daemon || true

# Copy toàn bộ mã nguồn và build file bootJar
COPY src ./src
RUN ./gradlew bootJar -x test --no-daemon

# ========================================================
# Stage 3: Chạy ứng dụng Spring Boot bằng JRE siêu nhẹ
# Lệnh build: docker build -t my-spring-image .
# ========================================================
FROM eclipse-temurin:21-jre-alpine AS app
WORKDIR /app

# Copy file jar từ Stage 2 (build)
COPY --from=build /app/build/libs/*.jar app.jar

# Khai báo cổng ứng dụng
EXPOSE 8080

# Cấu hình biến môi trường kết nối tới MySQL container
# Chú ý: 'mysql-db' là hostname do Docker Network tự động phân giải qua tên container
ENV SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/productdb?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true&createDatabaseIfNotExist=true
ENV SPRING_DATASOURCE_USERNAME=root
ENV SPRING_DATASOURCE_PASSWORD=root

ENTRYPOINT ["java", "-jar", "app.jar"]
