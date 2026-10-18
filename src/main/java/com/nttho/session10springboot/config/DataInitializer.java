package com.nttho.session10springboot.config;

import com.nttho.session10springboot.entity.Product;
import com.nttho.session10springboot.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final ProductRepository productRepository;

    @Override
    public void run(String... args) {
        if (productRepository.count() == 0) {
            log.info("Khởi tạo dữ liệu mẫu cho database...");
            productRepository.saveAll(List.of(
                    Product.builder()
                            .productName("Snack Oishi Cay")
                            .price(10.0)
                            .description("Bim bim cay cay giòn rụm")
                            .build(),
                    Product.builder()
                            .productName("Mì tôm siêu cay")
                            .price(15.5)
                            .description("Mì cay cấp độ 7 thơm ngon đậm đà")
                            .build(),
                    Product.builder()
                            .productName("Xoài non lắc muối tôm")
                            .price(25.0)
                            .description("Món ăn vặt best-seller chua cay mặn ngọt")
                            .build(),
                    Product.builder()
                            .productName("Trà sữa trân châu đường đen")
                            .price(35.0)
                            .description("Đậm vị trà, ngọt thanh, béo ngậy")
                            .build()
            ));
            log.info("Đã khởi tạo {} sản phẩm vào cơ sở dữ liệu MySQL!", productRepository.count());
        } else {
            log.info("Cơ sở dữ liệu đã có {} sản phẩm, bỏ qua bước khởi tạo mẫu.", productRepository.count());
        }
    }
}
