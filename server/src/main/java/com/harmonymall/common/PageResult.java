package com.harmonymall.common;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.io.Serializable;
import java.util.List;

/**
 * 分页结果
 */
@Data
@AllArgsConstructor
public class PageResult<T> implements Serializable {

    private List<T> list;
    private Long total;
    private Long page;
    private Long size;
}
