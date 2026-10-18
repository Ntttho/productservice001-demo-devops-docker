-- Script khởi tạo cơ sở dữ liệu và dữ liệu mẫu cho MySQL
CREATE DATABASE IF NOT EXISTS productdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE productdb;

CREATE TABLE IF NOT EXISTS products (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    price DOUBLE NOT NULL,
    description VARCHAR(500)
);

INSERT INTO products (product_name, price, description) VALUES
('Snack Oishi Cay', 10.0, 'Bim bim cay cay giòn rụm'),
('Mì tôm siêu cay', 15.5, 'Mì cay cấp độ 7 thơm ngon đậm đà'),
('Xoài non lắc muối tôm', 25.0, 'Món ăn vặt best-seller chua cay mặn ngọt'),
('Trà sữa trân châu đường đen', 35.0, 'Đậm vị trà, ngọt thanh, béo ngậy');
