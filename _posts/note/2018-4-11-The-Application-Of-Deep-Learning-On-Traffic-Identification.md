---
layout: post
categories: note
share: true
comments: true
title: 'The Application Of Deep Learning On Traffic Identification 笔记'
date: '2018-04-11T00:00:00'
modified: '2018-04-11T21:00:00'
tags: [Note, Machine Learning, Deep Learning, SAE]
author: Old Jack
hidelogo: true
---
**世界很大，字节也可以当作初始特征来用于机器学习。**

这是3年前 Black Hat 大会上的论文，来自360的一个团队。论文链接如下：[The Application Of Deep Learning On Traffic Identification](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&uact=8&ved=0ahUKEwij273grbLaAhVHNI8KHRFGDtsQFggsMAA&url=https%3A%2F%2Fwww.blackhat.com%2Fdocs%2Fus-15%2Fmaterials%2Fus-15-Wang-The-Applications-Of-Deep-Learning-On-Traffic-Identification-wp.pdf&usg=AOvVaw0gFY-xczK0adUHbdTIirYN)。

在有限的数据挖掘/机器学习经验中，大多数接触到的特征是字符串、数值、0,1布尔类型。这些东西大多也都是来自非常直观的原始特征，比如：航空公司名称、出发地代号、目的地代号、时间等等。这在某种程度上限制了我的想象力(想象力本身就比较匮乏)，直到看了这篇文章。

流量数据是图像、音频、自然语言文本之外的另一个领域，这个领域更多的是和网络状况分析、网络安全相关。相比于另外3者的巨大应用市场带来的驱动力，这个领域在近几年的中国互联网安全大会也不过只有这一篇论文而已。流量数据和图像音频数据略有不同的是，流量数据的抽象程度更高，没有直观的物理意义；和自然语言文本数据不同的是，流量数据在这个基础上又增加了一定的结构化含义。结构化有利也有弊，以http为例，对于在http规范中规定的报文头，这些字段的含义是很明显的，有助于人从中进行筛选、理解模型，这是利之一；对于不在http规范中的报文头，不同的应用会有很多自定义的报文头，这些报文头的含义即使是有专家系统也很难确定，那么是否作为特征以及怎么作为特征使用就成了结构化的一个弊。

这篇文章提出了以报文的字节作为特征来作为初始输入，使用一般的ANN或者SAE来学习新的特征，然后再使用其他的学习模型来进行流量的识别。每个字节代表着0-255的整数，再将其标准化，然后放入ANN和SAE中进行特征学习。根据ANN或SAE习得参数的绝对值，来找出相关性最高的25、100个字节以及相关性最低的300个字节。这样做还可以给专家系统进行精准的定位，来查看哪些字节是关键字节，可以人工进行深入研究。整个模型最后的结果也是非常好，对于未知协议的识别也比传统方法有了一定的提升。

在我看来，字节数据和图像、音频、自然语言文本本质上是一样的，因为都是计算机为了能模拟世界而用于存储和计算的数据，毕竟是机器学习。那么以后的一些问题中是否也可以考虑采用字节作为初始的特征呢？甚至可以把其它一些更原始更没有想过的东西作为特征放入模型呢？