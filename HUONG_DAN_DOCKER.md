# HƯỚNG DẪN HỌC DOCKER NETWORK VÀ DOCKER VOLUME VỚI SPRING BOOT & MYSQL

Tài liệu này được thiết kế để giúp bạn hiểu rõ bản chất của **Docker Network**, **Docker Volume**, cơ chế hoạt động của **Multi-stage Dockerfile**, và cách kết nối ứng dụng **Spring Boot (JPA)** với cơ sở dữ liệu **MySQL**.

---

## 1. Phân Tích Lỗi Sai Của File Dockerfile Ban Đầu (Trong Ảnh)

Trong bức ảnh mẫu, Dockerfile được viết như sau:

```dockerfile
# Stage 1: Create MySQL database with mock data
FROM mysql:8.0 AS mysql-db
ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=taskdb
COPY src/main/resources/db/taskdb.sql /docker-entrypoint-initdb.d/

# Stage 2: Build the application using Gradle
FROM gradle:8.5-jdk21 AS build
...
# Stage 3: Run the application
FROM eclipse-temurin:21-jre-alpine
...
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Tại sao viết như vậy là SAI BẢN CHẤT?

1. **Hiểu lầm về Multi-stage Build:**
   - Multi-stage build trong Docker dùng để **tối ưu dung lượng của 1 Image duy nhất** (Stage 1 build code $\rightarrow$ Stage 2 chép file JAR sang để chạy).
   - Lệnh `docker build` chỉ tạo ra **duy nhất 1 Image** từ stage cuối cùng (`Stage 3`).
   - Stage 1 `FROM mysql:8.0 AS mysql-db` hoàn toàn **bị bỏ qua**, nó **KHÔNG** hề sinh ra một MySQL container chạy ngầm nào cả!
2. **Lỗi khi chạy ứng dụng:**
   - Khi bạn chạy image được build ra, chỉ có file `app.jar` chạy.
   - Khi Spring Boot khởi động và tìm kết nối tới `jdbc:mysql://mysql-db:3306/...`, hệ thống sẽ văng lỗi **Communications link failure** hoặc **UnknownHostException: mysql-db** vì không có bất kỳ container MySQL nào đang chạy.
3. **Quy tắc cốt lõi của Docker:**
   - **Mỗi Container chỉ chịu trách nhiệm cho 1 dịch vụ (Single Concern):** 1 container chạy MySQL riêng, 1 container chạy Spring Boot riêng.
   - Để 2 container giao tiếp được với nhau $\rightarrow$ Cần **Docker Network**.
   - Để dữ liệu MySQL không bị biến mất khi tắt/xóa container $\rightarrow$ Cần **Docker Volume**.

---

## 2. Kiến Thức Trọng Tâm: Docker Network & Docker Volume

### 2.1. Docker Network là gì? Tại sao cần?
- Mặc định, mỗi container chạy trong một môi trường cô lập.
- Khi tạo một mạng bridge do người dùng tự định nghĩa (**User-defined Bridge Network**):
  ```bash
  docker network create devops-net
  ```
- **Tính năng quan trọng nhất:** **Automatic DNS Resolution (Tự động phân giải tên miền nội bộ)**.
  - Container Spring Boot có thể kết nối đến MySQL thông qua chính **tên container** (`container_name`) thay vì phải mò địa chỉ IP động.
  - Ví dụ: đặt tên container MySQL là `mysql-db`, thì trong Spring Boot chỉ cần đặt URL là `jdbc:mysql://mysql-db:3306/productdb`.

### 2.2. Docker Volume là gì? Tại sao cần?
- Các container có tính chất **ephemeral (tạm thời)**: Nếu bạn xóa container (`docker rm -f mysql-db`), toàn bộ dữ liệu database bên trong sẽ bị xóa sạch theo.
- **Docker Volume** lưu trữ dữ liệu tại một phân vùng an toàn trên máy chủ (Host OS) nằm ngoài vòng đời của container:
  ```bash
  docker volume create mysql_data
  ```
- Khi mount volume này vào thư mục lưu trữ dữ liệu của MySQL (`/var/lib/mysql`):
  - Dù container MySQL bị `docker stop`, `docker rm` hay crash, dữ liệu vẫn còn nguyên vẹn trên volume.
  - Khi tạo một container MySQL mới và gắn lại volume này, toàn bộ dữ liệu trước đó được khôi phục ngay lập tức.

---

## 3. Thực Hành Cách 1: Sử Dụng Lệnh Docker CLI (Khuyên Dùng Để Học Bản Chất)

Mở terminal tại thư mục gốc của project (`session10-springboot`):

### Bước 1: Build Docker Image cho Spring Boot
```bash
docker build -t springboot-product-app .
```
*(Lệnh này sử dụng file Dockerfile đã được tối ưu: dùng Gradle wrapper biên dịch và đóng gói bằng JRE 21 alpine).*

### Bước 2: Tạo Docker Network
```bash
docker network create devops-net
```
*Kiểm tra danh sách network:*
```bash
docker network ls
```

### Bước 3: Tạo Docker Volume
```bash
docker volume create mysql_data
```
*Kiểm tra danh sách volume:*
```bash
docker volume ls
```

### Bước 4: Chạy Container MySQL (Gắn cả Network và Volume)

> **Lưu ý trên Windows PowerShell:** Dùng `${PWD}` để lấy đường dẫn hiện tại:

```powershell
docker run -d `
  --name mysql-db `
  --network devops-net `
  -v mysql_data:/var/lib/mysql `
  -v ${PWD}/src/main/resources/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro `
  -e MYSQL_ROOT_PASSWORD=root `
  -e MYSQL_DATABASE=productdb `
  -p 3306:3306 `
  mysql:8.0
```

*(Nếu bạn dùng Git Bash hoặc Linux, thay `${PWD}` bằng `$(pwd)` và đổi dấu `` ` `` thành `\`)*

- **Giải thích các tham số:**
  - `--name mysql-db`: Đặt tên container là `mysql-db`.
  - `--network devops-net`: Gắn container vào mạng `devops-net`.
  - `-v mysql_data:/var/lib/mysql`: Gắn Docker Volume để giữ dữ liệu bền vững.
  - `-v .../init.sql:/docker-entrypoint-initdb.d/init.sql:ro`: File SQL mock data sẽ tự động được chạy khi database khởi tạo lần đầu.
  - `-e MYSQL_ROOT_PASSWORD=root`: Mật khẩu tài khoản root.
  - `-e MYSQL_DATABASE=productdb`: Tên database.

Kiểm tra log của MySQL xem đã sẵn sàng chưa:
```bash
docker logs -f mysql-db
```
*(Khi thấy thông báo `ready for connections`, nhấn `Ctrl + C` để thoát log).*

### Bước 5: Chạy Container Spring Boot (Gắn cùng Network với MySQL)

```powershell
docker run -d `
  --name product-service `
  --network devops-net `
  -p 8080:8080 `
  -e SPRING_DATASOURCE_URL="jdbc:mysql://mysql-db:3306/productdb?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true" `
  -e SPRING_DATASOURCE_USERNAME=root `
  -e SPRING_DATASOURCE_PASSWORD=root `
  springboot-product-app
```

- **Điểm mấu chốt ở đây:** URL kết nối là `jdbc:mysql://mysql-db:3306/productdb`. Nhờ có `--network devops-net`, Spring Boot sẽ phân giải được `mysql-db` trỏ thẳng tới IP nội bộ của MySQL container!

Xem log Spring Boot khởi động:
```bash
docker logs -f product-service
```
Bạn sẽ thấy dòng log:
`Đã khởi tạo 4 sản phẩm vào cơ sở dữ liệu MySQL!` và `Started Session10SpringbootApplication`.

---

## 4. Kiểm Tra Kết Quả (Test API)

Mở trình duyệt hoặc sử dụng cURL / Postman:

**Địa chỉ API:**
```
GET http://localhost:8080/api/products
```

**Dùng cURL trong terminal:**
```bash
curl http://localhost:8080/api/products
```

**Dữ liệu JSON trả về từ MySQL:**
```json
[
  {
    "id": 1,
    "productName": "Snack Oishi Cay",
    "price": 10.0,
    "description": "Bim bim cay cay giòn rụm"
  },
  {
    "id": 2,
    "productName": "Mì tôm siêu cay",
    "price": 15.5,
    "description": "Mì cay cấp độ 7 thơm ngon đậm đà"
  },
  {
    "id": 3,
    "productName": "Xoài non lắc muối tôm",
    "price": 25.0,
    "description": "Món ăn vặt best-seller chua cay mặn ngọt"
  },
  {
    "id": 4,
    "productName": "Trà sữa trân châu đường đen",
    "price": 35.0,
    "description": "Đậm vị trà, ngọt thanh, béo ngậy"
  }
]
```

---

## 5. Thí Nghiệm Chứng Minh Sức Mạnh Của Docker Volume

Hãy thực hiện thí nghiệm này để hiểu tại sao Docker Volume quan trọng:

1. **Xóa hoàn toàn container MySQL:**
   ```bash
   docker rm -f mysql-db
   ```
2. **Khởi chạy một container MySQL mới tinh, vẫn mount vào volume `mysql_data` cũ:**
   ```powershell
   docker run -d `
     --name mysql-db `
     --network devops-net `
     -v mysql_data:/var/lib/mysql `
     -e MYSQL_ROOT_PASSWORD=root `
     -e MYSQL_DATABASE=productdb `
     -p 3306:3306 `
     mysql:8.0
   ```
3. **Gọi lại API:**
   ```bash
   curl http://localhost:8080/api/products
   ```
   $\rightarrow$ **Kết quả:** Dữ liệu sản phẩm vẫn còn nguyên 100%! Không hề bị mất đi dù container cũ đã bị hủy. Đó chính là nhờ **Docker Volume**.

---

## 6. Thực Hành Cách 2: Triển Khai Nhanh Với Docker Compose

Trong thực tế doanh nghiệp, người ta dùng `docker-compose` để tự động hóa toàn bộ các bước tạo Network, Volume và chạy đồng thời các container chỉ bằng **1 lệnh duy nhất**.

Tệp `docker-compose.yml` đã được cấu hình sẵn trong project.

### Các lệnh quản lý:

1. **Khởi chạy toàn bộ hệ thống (build image + tạo network + tạo volume + chạy container):**
   ```bash
   docker compose up -d --build
   ```

2. **Theo dõi log của toàn bộ hệ thống:**
   ```bash
   docker compose logs -f
   ```

3. **Theo dõi riêng log của Spring Boot:**
   ```bash
   docker compose logs -f product-service
   ```

4. **Dừng hệ thống (Dữ liệu trong Volume vẫn được bảo lưu):**
   ```bash
   docker compose down
   ```

5. **Dừng hệ thống và XÓA CẢ VOLUME (chỉ dùng khi muốn reset sạch dữ liệu):**
   ```bash
   docker compose down -v
   ```

---

## 7. Tổng Kết Các Thay Đổi Trong Dự Án

| Thành phần | Chi tiết đã thực hiện |
| :--- | :--- |
| **build.gradle** | Thêm thư viện `spring-boot-starter-data-jpa` và driver `mysql-connector-j`. |
| **Product.java** | Đánh dấu entity với `@Entity`, `@Table(name = "products")`, `@Id`, `@GeneratedValue`. |
| **ProductRepository.java** | Kế thừa `JpaRepository<Product, Long>` để thao tác cơ sở dữ liệu. |
| **ProductController.java** | Gọi `productRepository.findAll()` để trả về dữ liệu lấy trực tiếp từ MySQL. |
| **DataInitializer.java** | Tự động thêm dữ liệu mẫu ban đầu nếu bảng trong MySQL chưa có dữ liệu. |
| **init.sql** | File SQL mẫu tạo database và nạp dữ liệu ban đầu cho MySQL container. |
| **Dockerfile** | Viết lại chuẩn Multi-stage build (Stage 1: Build JAR, Stage 2: JRE Runtime). |
| **docker-compose.yml** | Khai báo 2 services `mysql-db` & `product-service`, kèm `networks` và `volumes`. |
