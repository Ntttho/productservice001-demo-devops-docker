# HƯỚNG DẪN CHI TIẾT QUY TRÌNH CI/CD VỚI GITHUB ACTIONS

Tài liệu này giải thích toàn bộ quy trình **CI (Continuous Integration)** và **CD (Continuous Deployment)** tự động cho ứng dụng **Spring Boot + MySQL + Docker** lên **VPS Server**.

---

## 1. Tổng Quan Về CI/CD

- **CI (Continuous Integration - Tích hợp liên tục):**
  - Tự động kiểm tra chất lượng code và chạy **Unit Tests** ngay khi có commit/pull request.
  - Tự động biên dịch và build file JAR.
  - Tự động đóng gói **Docker Image** và đẩy lên **Docker Hub**.
- **CD (Continuous Deployment - Triển khai liên tục):**
  - Tự động kết nối SSH vào **VPS Server** (`103.72.57.95`).
  - Kéo Docker Image mới nhất từ Docker Hub về server.
  - Khởi động lại container Spring Boot mà không làm mất dữ liệu Database.

---

## 2. Kiến Trúc Toàn Diện Của Pipeline CI/CD

File cấu hình: [`.github/workflows/ci.yml`](file:///d:/devops/session10-springboot/.github/workflows/ci.yml)

```mermaid
flowchart TD
    A[Git Push lên nhánh main] --> B[Job 1: Build & Test - CI]
    
    subgraph Job 1: Build & Test Java
        B1[Khởi tạo MySQL 8.0 Service Container]
        B2[Setup JDK 21 Temurin + Gradle Cache]
        B3[Chạy Unit Tests ./gradlew test]
        B4[Build BootJar & Lưu trữ Artifact]
    end
    
    B --> C[Job 2: Docker Build & Push - CI]
    
    subgraph Job 2: Build & Push Docker Image
        C1[Docker Buildx + Cache GitHub Actions]
        C2[Login Docker Hub qua Secrets]
        C3[Build Multi-stage Dockerfile]
        C4[Push Image :latest và :sha lên Docker Hub]
    end
    
    C --> D[Job 3: Deploy lên VPS - CD]
    
    subgraph Job 3: Continuous Deployment
        D1[Kết nối SSH vào VPS bằng Private Key]
        D2[Docker pull image mới nhất từ Docker Hub]
        D3[Dừng & xóa container product-service cũ]
        D4[Chạy container mới trong mạng my-network]
        D5[Dọn dẹp image rác trên VPS]
    end
```

---

## 3. Các Bước Cấu Hình GitHub Secrets (Bắt Buộc Cho CI/CD)

Để pipeline có thể tự động đẩy Docker Image lên Docker Hub và SSH vào VPS để deploy, bạn cần thiết lập các Secret trên GitHub Repository.

### 3.1. Các Secret Cần Thiết:

| Tên Secret | Ý nghĩa | Giá trị mẫu |
| :--- | :--- | :--- |
| `DOCKERHUB_USERNAME` | Tên tài khoản Docker Hub | Tên user Docker Hub của bạn |
| `DOCKERHUB_TOKEN` | Access Token của Docker Hub | Mã `dckr_pat_...` (tạo từ Docker Hub) |
| `SSH_HOST` | Địa chỉ IP của máy chủ VPS | `103.72.57.95` |
| `SSH_USER` | Tên người dùng SSH trên VPS | `nttho` |
| `SSH_PRIVATE_KEY` | Toàn bộ nội dung SSH Private Key | Nội dung file `$HOME\.ssh\id_rsa` |
| `SSH_PORT` *(tùy chọn)* | Cổng SSH | `22` (mặc định) |

---

### 3.2. Cách Lấy Thông Tin & Thêm Vào GitHub:

#### Bước 1: Lấy Docker Hub Access Token
1. Truy cập [Docker Hub](https://hub.docker.com/) -> Đăng nhập.
2. Bấm vào Avatar góc phải trên -> **Account Settings** -> **Personal access tokens**.
3. Bấm **Generate new token**, đặt tên (vd: `github-actions-token`), chọn quyền `Read & Write` -> Bấm **Generate**.
4. **Copy mã token** được tạo.

#### Bước 2: Lấy SSH Private Key
Trên máy cá nhân, mở PowerShell và copy toàn bộ nội dung:
```powershell
Get-Content "$HOME\.ssh\id_rsa"
```
*(Copy toàn bộ từ dòng `-----BEGIN OPENSSH PRIVATE KEY-----` đến hết dòng `-----END OPENSSH PRIVATE KEY-----`).*

#### Bước 3: Thêm Secrets vào GitHub Repository
1. Mở repo GitHub: [https://github.com/Ntttho/productservice001-demo-devops-docker](https://github.com/Ntttho/productservice001-demo-devops-docker).
2. Vào tab **Settings** -> Danh mục bên trái chọn **Secrets and variables** -> **Actions**.
3. Bấm nút xanh **New repository secret** và lần lượt thêm:
   - Secret 1: Name: `DOCKERHUB_USERNAME` -> Value: tên user của bạn
   - Secret 2: Name: `DOCKERHUB_TOKEN` -> Value: token vừa copy ở Bước 1
   - Secret 3: Name: `SSH_HOST` -> Value: `103.72.57.95`
   - Secret 4: Name: `SSH_USER` -> Value: `nttho`
   - Secret 5: Name: `SSH_PRIVATE_KEY` -> Value: nội dung khóa vừa copy ở Bước 2

---

## 4. Cách Kích Hoạt Và Theo Dõi Pipeline

Sau khi cấu hình Secrets xong, bạn chỉ cần commit và push:

```powershell
git add .github/workflows/ci.yml HUONG_DAN_CI.md
git commit -m "feat(cicd): add complete CI/CD pipeline with auto deployment to VPS"
git push origin main
```

### Theo Dõi Quá Trình Chạy:
1. Vào tab **Actions** trên GitHub.
2. Bạn sẽ thấy 3 Job chạy lần lượt:
   - ✅ **Build & Test (Java 21)**: Chạy test và đóng gói file JAR.
   - ✅ **Build & Push Docker Image**: Đóng gói Docker và đẩy lên Docker Hub.
   - ✅ **Deploy to VPS Server**: SSH vào VPS và triển khai container mới nhất!
3. Sau khi Job Deploy hoàn tất, bạn có thể kiểm tra trực tiếp API từ trình duyệt:
   ```
   http://103.72.57.95:8080/api/products
   ```