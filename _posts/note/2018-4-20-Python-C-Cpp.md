---
layout: post
categories: note
share: true
comments: true
title: 'Python 调用 C/C++ 方法'
date: '2018-04-20T00:00:00'
modified: '2018-04-20T21:00:00'
tags: [Note, Python, C, C++]
author: Old Jack
hidelogo: true
---
之前写 Density Peaks Clustering 算法的时候，遇到了性能瓶颈，所以对 Python 调用 C/C++ 的方法产生了兴趣，现在根据 Google 结果进行下总结，没有干货...

# 一、 ctypes

[ctypes](https://docs.python.org/3/library/ctypes.html) 是 Python 的一个原生模块，可以用来将 Python 的内置类型转换为对应的 C 类型、调用 C/C++ 库的函数。根据 StackOverFlow 论坛和知乎的说法，ctypes 是最简单的调用方法之一，不需要修改太多的 Python 和 C/C++ 代码。简单的代价是参数转换时会有一定的性能瓶颈，在项目没有性能需求时，可以用来提高开发效率和维护成本。

下面举一个简单的例子，下面的 C++ 代码的功能是输出一个文件的所有内容(fopen 官方示例代码)，然后我们用 Python 来调用这个函数：

test.h:
```cpp
#ifndef TEST_H
#define TEST_H

#include <stdio.h>
#include <stdlib.h>

extern "C" int PrintFile(const char *filename);

#endif
```

test.cpp：
```cpp
#include "test.h"

extern "C"
int PrintFile(const char *filename) {
    puts(filename);
    FILE *fp = fopen(filename, "r");
    if(!fp) {
        perror("File opening failed");
        return EXIT_FAILURE;
    }

    int c; // note: int, not char, required to handle EOF
    while ((c = fgetc(fp)) != EOF) { // standard C I/O file reading loop
        putchar(c);
    }

    if (ferror(fp))
        puts("I/O error when reading");
    else if (feof(fp))
        puts("End of file reached successfully");

    fclose(fp);
    return 0;
}
```

编译:

```shell
clang++ test.cpp -o libtest.so -dynamiclib
```

Python 调用代码：
```python
# -*- coding: utf-8 -*-

from ctypes import *

# load dynamic library
cdll.LoadLibrary("./test.so")
test = CDLL("./test.so")

# calling functions
filename_p = "./test.cpp".encode('utf-8') # 即使文件用utf-8编码，仍要加encode，暂时不知为什么...

# 先转换成 c_char_p 类型再传入
filename_p_converted = c_char_p(filename_p)
test.PrintFile(filename_p_converted)

# 将调用的函数参数类型转换为相应的类型(ctypes module 会自行进行转换)，直接穿入字符串
test.PrintFile.argtypes = [c_char_p]
test.PrintFile(filename_p)
```

目前接口中只需要文件名字符串，所以只需要传入一个 char *即可，ctypes 中对应着 c_char_p 这种类型。

# 二、 SWIG

[SWIG](http://www.swig.org) 方法目前还没有亲身实践过，官方教程中的例子如下：

```c
/* File : example.c */

#include <time.h>
double My_variable = 3.0;

int fact(int n) {
    if (n <= 1) return 1;
    else return n*fact(n-1);
}

int my_mod(int x, int y) {
    return (x%y);
}
	
char *get_time() {
    time_t ltime;
    time(&ltime);
    return ctime(&ltime);
}
```

SWIG 文件：

```
/* example.i */
%module example
%{
/* Put header files here or function declarations like below */
extern double My_variable;
extern int fact(int n);
extern int my_mod(int x, int y);
extern char *get_time();
%}

extern double My_variable;
extern int fact(int n);
extern int my_mod(int x, int y);
extern char *get_time();
```

这个给我的第一感觉和 ZeroC 的 [Ice](https://zeroc.com/products/ice) 框架很像，二者都定义了可供多种语言调用的接口形式。为了保证通用性，这势必会带来一些小型项目上不必要的冗余，这是不可避免的问题；同时结构化的配置文件意味着一定的学习成本。作为一个第三方库，其依赖、稳定性、潜在的 Bug 也是必须要考虑的问题。在无多语言调用 C/C++ 代码时，SWIG的优势或许将不那么明显。不过值得一提的是，[TensorFlow](https://www.tensorflow.org) 中 Python 调用 C++ 用的就是 SWIG，毕竟要提供 Java、Python、Go 三种语言的api，所以 SWIG 是比较合适的选择。

# 三、 Boost.Python

大名鼎鼎的 Boost 库。关于 Boost 的说法有很多，而我又没有用过，所以不好作出判断。本着对于第三方库应该多加小心的原则，或许我暂时不会去考虑用 [Boost.Python](https://github.com/boostorg/python)。

[StackOverFlow 论坛的一篇回答中](https://stackoverflow.com/questions/9084111/is-wrapping-c-library-with-ctypes-a-bad-idea)提及到：

1. The only downsides are increased compile time (boost::python makes extensive use of templates);
2. sometimes opaque error messages if you don't get things quite right;
3. Another problem is the strong coupling of boost and python versions. For example, if you upgrade your python version, you will have to rebuild the version of boost.

# 四、 Python/C API

Python [官方](https://docs.python.org/3/c-api/index.html)的API，也就是“手写 module”方式。该种方式在理论上是运行效率和灵活性最高的方式，适用于有极高性能需求的项目，以及需要独立发行的第三方库。代价就是要对 Python 的实现要有一定的了解，同时要深入阅读 API 文档，以及开发时间。

# 五、 Cython

[Cython Github repo](https://github.com/cython/cython) 介绍：
> Cython is a language that makes writing C extensions for Python as easy as Python itself. The Cython language is very close to the Python language, but Cython additionally supports calling C functions and declaring C types on variables and class attributes. This allows the compiler to generate very efficient C code from Cython code.

知乎和 StackOverFlow 论坛对于 Cython 的运行效率和开发效率都给出了较高的评价。Brett Cannon (Principal software engineer at Microsoft) 在其博文 [Try to not use the Python C API directly](https://snarky.ca/try-to-not-use-the-c-api-directly/)中指出：

> If you're using CPython's C API for performance then what you want to use will depend on whether you are using NumPy in your code. If you are then you should see if Numba fits your needs. It will apply a JIT to your NumPy code by doing nothing more than adding a decorator to some functions which is about as easy as it can get.
>
> If your performance needs extend beyond Numba, then Cython will be your best bet. While you will need to write in Cython's hybrid language, it will probably be the easiest way to get better performance short of writing C code directly.
>
> If writing C code for performance appeals to you then you can use CFFI or SWIG to wrap your hand-rolled C code. But please do consider Numba and/or Cython first as they will be easier to use for good performance gains.

# 六、 CFFI(C Foreign Function Interface)

[CFFI](https://github.com/cffi/cffi)官方文档简介：
> C Foreign Function Interface for Python. Interact with almost any C code from Python, based on C-like declarations that you can often copy-paste from header files or documentation.

示例代码(官方教程)：

```python
# file "example_build.py"

# Note: we instantiate the same 'cffi.FFI' class as in the previous
# example, but call the result 'ffibuilder' now instead of 'ffi';
# this is to avoid confusion with the other 'ffi' object you get below

from cffi import FFI
ffibuilder = FFI()

ffibuilder.set_source("_example",
   r""" // passed to the real C compiler,
        // contains implementation of things declared in cdef()
        #include <sys/types.h>
        #include <pwd.h>

        struct passwd *get_pw_for_root(void) {
            return getpwuid(0);
        }
    """,
    libraries=[])   # or a list of libraries to link with
    # (more arguments like setup.py's Extension class:
    # include_dirs=[..], extra_objects=[..], and so on)

ffibuilder.cdef("""
    // declarations that are shared between Python and C
    struct passwd {
        char *pw_name;
        ...;     // literally dot-dot-dot
    };
    struct passwd *getpwuid(int uid);     // defined in <pwd.h>
    struct passwd *get_pw_for_root(void); // defined in set_source()
""")

if __name__ == "__main__":
    ffibuilder.compile(verbose=True)
```

# 七、 pybind11

[Github repo](https://github.com/pybind/pybind11) 简介：
> pybind11 is a lightweight header-only library that exposes C++ types in Python and vice versa, mainly to create Python bindings of existing C++ code. Its goals and syntax are similar to the excellent Boost.Python library by David Abrahams: to minimize boilerplate code in traditional extension modules by inferring type information using compile-time introspection.
> 
> The main issue with Boost.Python—and the reason for creating such a similar project—is Boost. Boost is an enormously large and complex suite of utility libraries that works with almost every C++ compiler in existence. This compatibility has its cost: arcane template tricks and workarounds are necessary to support the oldest and buggiest of compiler specimens. Now that C++11-compatible compilers are widely available, this heavy machinery has become an excessively large and unnecessary dependency.
> 
> Think of this library as a tiny self-contained version of Boost.Python with everything stripped away that isn't relevant for binding generation. Without comments, the core header files only require ~4K lines of code and depend on Python (2.7 or 3.x, or PyPy2.7 >= 5.7) and the C++ standard library. This compact implementation was possible thanks to some of the new C++11 language features (specifically: tuples, lambda functions and variadic templates). Since its creation, this library has grown beyond Boost.Python in many ways, leading to dramatically simpler binding code in many common situations.

因为其依赖于 C++11 所以要根据具体的项目来看是否适合。[Caffe2](https://caffe2.ai) 框架的实现使用了 pybind11。

<div class="text-divider"></div>

需要学习的还很多，不过步子太大容易扯到蛋，不骄不躁，相信自己的节奏和判断。