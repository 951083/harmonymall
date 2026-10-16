package com.harmonymall;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class HarmonyMallApplication {

    public static void main(String[] args) {
        SpringApplication.run(HarmonyMallApplication.class, args);
        System.out.println("HarmonyMall server started: http://localhost:8080/api");
    }
}
