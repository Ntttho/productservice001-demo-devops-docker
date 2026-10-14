package com.nttho.session10springboot.controller;

import com.nttho.session10springboot.entity.Product;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/api/products")
public class ProductController {
    private final List<Product> products = List.of(
            new Product(1L, "snack oxi kay", 10.0, "so delicious"),
            new Product(2L, "mi tom sieu kay", 13.0, "nhieu ot tang kem xuc xich..."),
            new Product(3L, "xoai non, coc tron", 20.0, "do an vat best saler")
    );


    @GetMapping
    public List<Product> findAllProducts(){
        return products;
    }
}
