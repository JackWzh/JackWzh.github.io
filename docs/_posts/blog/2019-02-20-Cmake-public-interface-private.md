---
layout: post
categories: blog
share: true
comments: true
title: 'Cmake PRIVATE|INTERFACE|PUBLIC 选项'
date: '2019-02-20T00:00:00'
modified: '2019-02-20T21:00:00'
tags: [Blog, Cmake]
author: Old Jack
hidelogo: true
---

曾经被 CMake 中的 PRIVATE、INTERFACE、PUBLIC 参数弄懵了很久，其实这个东西很简单和 C/C++ 编译器本身的参数没有任何关系，单纯是一个依赖解决的工具。

在 C/C++ 中，动态库/静态库之间的链接关系是非常需要注意的，一个不小心就有可能漏掉了某个库，导致找不到符号。根据库之间的不同关系，要有选择性地使用这三个中的某一个。比如说 liba --> libb，libb 依赖于 liba，但是只在 libb 内部使用了 liba 中的内容，那么这个时候就应该选择 PRIVATE，在实际生成的比如 makefile 中，链接 libb 的时候就会有 liba；但是如果libb的内部实现不使用 liba，但是其参数中使用了 liba 中的结构体/类/函数，那么就应该使用 INTERFACE，在世纪生成的 makefile 中，链接 libb 的时候就会有 liba，但是如果有某个库 libc 链接了 libb，并且是以 PRIVATE 或者 PUBLIC 模式链接的，那么在链接 libc 的时候，就会有 liba 出现。最后如果 libb 内部和接口中都使用了 liba 中的内容，那么只要链接了 libb 的库/可执行程序，在其生成的 makefile 文件中都会链接 liba。

之前的一个误区就是这个参数是和 gcc 的参数有关，其实不然，就像上面写的这么简单，过去真的是太蠢了。
