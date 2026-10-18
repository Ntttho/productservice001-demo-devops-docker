# HƯỚNG DẪN THỰC HÀNH DOCKER NETWORK & DOCKER VOLUME
*(Dành riêng cho thực hành bằng dòng lệnh Docker CLI - Không dùng Docker Compose)*

Tài liệu này hướng dẫn bạn cách hiểu và làm chủ **Docker Network** và **Docker Volume** thông qua việc triển khai ứng dụng **Spring Boot (JPA)** kết nối với **MySQL**.

---

## 1. Hiểu Rõ Về Cấu Trúc File Dockerfile (3 Stages)

Trong file `Dockerfile`, chúng ta có 3 stages:

```dockerfile
# Stage 1: Build Image MySQL chứa sẵn dữ liệu mẫu
FROM mysql:8.0 AS mysql-db
...

# Stage 2: Build file JAR từ mã nguồn Java bằng Gradle
FROM eclipse-temurin:21-jdk-alpine AS build
...

# Stage 3: Chạy ứng dụng Spring Boot bằng JRE nhẹ
FROM eclipse-temurin:21-jre-alpine AS app
...
```

### Tại sao lại gộp cả MySQL và Spring Boot vào chung 1 file Dockerfile?
* Bình thường, lệnh `docker build -t my-spring-image .` sẽ chạy đến stage cuối cùng (`Stage 3`) để tạo ra image của **Spring Boot**.
* Nhưng Docker hỗ trợ cờ `--target <stage-name>`. Khi bạn gõ:
  ```bash
  docker build --target mysql-db -t my-mysql-image .
  ```
  Docker sẽ **chỉ chạy Stage 1** và tạo ra ngay một image MySQL chứa sẵn file script SQL dữ liệu mẫu!
* **Quy tắc vàng:** Dù nằm chung trong 1 file `Dockerfile`, khi chạy chúng ta vẫn phải chạy thành **2 container riêng biệt** (1 container chạy MySQL và 1 container chạy Spring Boot). Để 2 container này nói chuyện được với nhau, chúng ta sử dụng **Docker Network**; và để giữ dữ liệu MySQL không bị mất, ta dùng **Docker Volume**.

---

## 2. Kiến Thức Cốt Lõi Cần Nhớ

### 2.1. Docker Network là gì?
* Mỗi container khi tạo ra mặc định nằm trong mạng cô lập.
* Khi ta tạo mạng riêng (`docker network create devops-net`) và đưa 2 container vào chung mạng này:
  * Hai container có thể giao tiếp với nhau qua **chính tên container** (tính năng DNS nội bộ của Docker).
  * Trong Spring Boot, URL kết nối chỉ cần ghi:
    `jdbc:mysql://mysql-db:3306/productdb`
    *(trong đó `mysql-db` là tên container MySQL).*

### 2.2. Docker Volume là gì?
* Container có tính chất tạm thời: nếu bạn xóa container (`docker rm`), toàn bộ database bên trong container cũng biến mất hoàn toàn.
* **Docker Volume** tạo ra một vùng lưu trữ độc lập trên máy chủ host (`docker volume create mysql_data`).
* Khi ta gắn volume này vào thư mục lưu trữ của MySQL (`/var/lib/mysql`), thì dù container MySQL có bị xóa đi và tạo lại bao nhiêu lần, dữ liệu bảng và bản ghi vẫn còn nguyên vẹn 100%!

---

## 3. Các Bước Thực Hành Chi Tiết Bằng Dòng Lệnh

Mở **PowerShell** hoặc **Terminal** tại thư mục dự án (`session10-springboot`):

### Bước 1: Build 2 Docker Image từ Dockerfile

#### 1.1. Build Image MySQL (dùng cờ `--target mysql-db`):
```bash
docker build --target mysql-db -t my-mysql-image .
```

#### 1.2. Build Image Spring Boot (chạy toàn bộ Dockerfile):
```bash
docker build -t my-spring-image .
```

*Kiểm tra 2 image vừa tạo:*
```bash
docker images
```

---

### Bước 2: Tạo Docker Network và Docker Volume

#### 2.1. Tạo mạng chung cho 2 container:
```bash
docker network create devops-net
```

#### 2.2. Tạo volume để lưu trữ dữ liệu MySQL bền vững:
```bash
docker volume create mysql_data
```

*Kiểm tra:*
```bash
docker network ls
docker volume ls
```

---

### Bước 3: Khởi chạy Container MySQL

Chạy container MySQL với tên là `mysql-db`, gắn vào mạng `devops-net` và volume `mysql_data`:

**Lệnh chạy trên Windows PowerShell:**
```powershell
docker run -d `
  --name mysql-db `
  --network devops-net `
  -v mysql_data:/var/lib/mysql `
  -e MYSQL_ROOT_PASSWORD=root `
  -e MYSQL_DATABASE=productdb `
  -p 3306:3306 `
  my-mysql-image
```

*(Nếu bạn dùng Git Bash hoặc Linux/macOS, hãy đổi dấu `` ` `` thành dấu `\`)*

**Giải thích các tham số:**
* `-d`: Chạy ngầm (detached mode).
* `--name mysql-db`: Đặt tên container là `mysql-db` (đây cũng chính là hostname trong mạng nội bộ).
* `--network devops-net`: Cho container gia nhập mạng `devops-net`.
* `-v mysql_data:/var/lib/mysql`: Gắn volume `mysql_data` vào thư mục dữ liệu của MySQL.
* `-p 3306:3306`: Mở cổng 3306 để có thể kết nối từ máy thật (DBeaver, MySQL Workbench nếu cần).
* `my-mysql-image`: Tên image MySQL đã build ở Bước 1.1.

*Kiểm tra xem MySQL đã sẵn sàng nhận kết nối chưa:*
```bash
docker logs -f mysql-db
```
*(Khi thấy dòng chữ `ready for connections`, nhấn tổ hợp phím `Ctrl + C` để thoát màn hình xem log).*

---

### Bước 4: Khởi chạy Container Spring Boot

Chạy container Spring Boot và cho nó kết nối tới MySQL thông qua hostname `mysql-db`:

**Lệnh chạy trên Windows PowerShell:**
```powershell
docker run -d `
  --name product-service `
  --network devops-net `
  -p 8080:8080 `
  -e SPRING_DATASOURCE_URL="jdbc:mysql://mysql-db:3306/productdb?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true" `
  -e SPRING_DATASOURCE_USERNAME=root `
  -e SPRING_DATASOURCE_PASSWORD=root `
  my-spring-image
```

*Theo dõi quá trình Spring Boot khởi động:*
```bash
docker logs -f product-service
```
Bạn sẽ thấy log Spring Boot kết nối thành công tới MySQL và khởi tạo dữ liệu:
```text
Đã khởi tạo 4 sản phẩm vào cơ sở dữ liệu MySQL!
Started Session10SpringbootApplication in ... seconds
```
*(Nhấn `Ctrl + C` để thoát xem log).*

---

### Bước 5: Kiểm tra kết quả (Test API)

Mở trình duyệt web hoặc dùng lệnh cURL để lấy danh sách sản phẩm từ MySQL:

**URL truy cập:**
```
http://localhost:8080/api/products
```

**Hoặc chạy cURL trong terminal:**
```bash
curl http://localhost:8080/api/products
```

**Dữ liệu JSON nhận được từ MySQL:**
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

## 4. Thí Nghiệm Kiểm Chứng Docker Volume (Thực Hành Rất Quan Trọng)

Để chứng minh **Docker Volume** thực sự bảo vệ dữ liệu khi container bị mất:

1. **Xóa hoàn toàn container MySQL:**
   ```bash
   docker rm -f mysql-db
   ```
   *(Lúc này container MySQL đã bị hủy hoàn toàn).*

2. **Tạo lại một container MySQL mới tinh, vẫn trỏ vào volume `mysql_data`:**
   ```powershell
   docker run -d `
     --name mysql-db `
     --network devops-net `
     -v mysql_data:/var/lib/mysql `
     -e MYSQL_ROOT_PASSWORD=root `
     -e MYSQL_DATABASE=productdb `
     -p 3306:3306 `
     my-mysql-image
   ```

3. **Gọi lại API để kiểm tra:**
   ```bash
   curl http://localhost:8080/api/products
   ```
   $\rightarrow$ **Kết quả:** Dữ liệu vẫn còn nguyên vẹn 100%! Không hề bị mất đi. Đó chính là giá trị cốt lõi của **Docker Volume**.

---

## 5. Dọn Dẹp Sau Khi Học Xong (Clean Up)

Khi học xong, bạn có thể dọn dẹp các tài nguyên:

```bash
# 1. Dừng và xóa 2 container
docker rm -f product-service mysql-db

# 2. Xóa mạng devops-net
docker network rm devops-net

# 3. Xóa volume mysql_data (chỉ chạy khi muốn xóa toàn bộ dữ liệu database)
docker volume rm mysql_data

# 4. Xóa 2 image đã build (nếu muốn giải phóng dung lượng ổ đĩa)
docker rmi my-spring-image my-mysql-image
```

---

## 6. Bảng Tra Cứu Nhanh Các Lệnh Docker CLI Đã Học

| Thao tác | Lệnh Docker CLI |
| :--- | :--- |
| **Build riêng 1 stage** | `docker build --target <tên-stage> -t <tên-image> .` |
| **Build toàn bộ Dockerfile** | `docker build -t <tên-image> .` |
| **Tạo Network** | `docker network create <tên-network>` |
| **Tạo Volume** | `docker volume create <tên-volume>` |
| **Gắn container vào mạng** | `--network <tên-network>` trong `docker run` |
| **Gắn volume vào container** | `-v <tên-volume>:<đường-dẫn-trong-container>` |
| **Xem log container** | `docker logs -f <tên-container>` |
| **Xóa container đang chạy** | `docker rm -f <tên-container>` |
