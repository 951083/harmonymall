package com.harmonymall.common;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

/**
 * JSON 工具（订单快照 / Redis 缓存序列化）
 *
 * 注意：必须注册 JavaTimeModule。实体里有 LocalDateTime 字段（createdAt/updatedAt），
 * 裸 ObjectMapper 序列化到它时会抛异常 → 被 catch 吞掉返回 "{}"，
 * 曾把商品详情缓存写成空对象（第二次进商品页名称丢失、显示"已售 undefined"）。
 */
public final class JsonUtils {

    private static final ObjectMapper MAPPER = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

    private JsonUtils() {
    }

    public static String toJson(Object obj) {
        try {
            return MAPPER.writeValueAsString(obj);
        } catch (Exception e) {
            return "{}";
        }
    }

    public static <T> T parse(String json, Class<T> clazz) {
        try {
            return MAPPER.readValue(json, clazz);
        } catch (Exception e) {
            return null;
        }
    }
}
