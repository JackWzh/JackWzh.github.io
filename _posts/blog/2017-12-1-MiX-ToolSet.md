---
layout: post
categories: blog
share: true
comments: true
title: 'WiX ToolSet 制作 Windows 安装包（2017.12.7 更新）'
date: '2017-12-01T21:00:00'
modified: '2017-12-01T21:30:00'
tags: [Blog, C#, WiX, Installer]
author: Old Jack
hidelogo: true
---
前两天又接了一个活，给产品制作一个安装包。

首先肯定是先Google之，Google后首先使用了 Windows Setup Project 来制作安装包，确实很简单，非常容易上手，不需要任何编程就可以完成制作一个.msi安装程序。但是有几个小问题：

1. 无在安装结束的窗口上添加安装后运行程序的选项。Google的结果是可以用一个javascript程序来实现，但是这个方法感觉并不是很优雅，也不知道会不会有其他的坑，所以没有采用这个方案。
2. 无法检测并安装.NET Framework 4.5.1。在依赖项里只有4.5.2和更高版本的.NET Framework，而项目是基于4.5.1的。其实这不是什么大的问题，一般不会有什么兼容性的问题，不过既然是领导的需求，就尽力尝试一下吧。
3. 无法将.msi文件和 .NET Framework 依赖嵌入Setup.exe中。我并没有刻意地去找怎么做，而是根据网上教程基于7zip制作了一个封装程序，这个解决方案也不是很优雅，所以不打算采取这个方案。

除了 Windows Setup Project，还有其他的几个选项：WiX ToolSet，Advanced Installer，InstallShield。后两个都是付费的软件，7天试用，又没找到破解，所以选择使用WiX这个免费的安装包制作框架。如果有经济支持的话，大家或许可以尝试一下 Advanced Installer 和 InstallShield。

WiX ToolSet 我个人理解为对 Installer 进行了封装，然后通过编写 .xml 文件来制作安装程序。相比于Windows Setup Project，这个工具集并不是很直观，但是它将很多 Setup Project 无法提供的 api 暴露了出来，可以对安装程序进行更多的定制和修改。接下来简单介绍一下我学习的过程来快速上手。

个人认为学习一个框架最好的方式是看样例+看文档，所以第一步是找一个使用 WiX ToolSet 的开源项目。在 Github 上搜索 WiX example，找到了下面的这个项目：[lomomike/WixInstallerExample](https://github.com/lomomike/WixInstallerExample)。对照生成的安装程序阅读源码，对于WiX的基本使用方法就会有了一个大概的了解。

接下来就是参考官方文档然后进行定制和修改。在这个过程中，我建议看官网上的 [reference](http://wixtoolset.org/documentation/manual/v3/) 而不是看 tutorial，tutorial 个人感觉有些杂乱无章，让人get不到点，相比之下 reference 倒是更条理清晰，也更解决关键点。就比如解决 .NET Framework 依赖检查和安装这个问题，详情可见：[How To: Install the .NET Framework Using Burn](http://wixtoolset.org/documentation/manual/v3/howtos/redistributables_and_install_checks/install_dotnet.html)，这里面就写的很清楚很清晰，一步一步怎么去做。

一个制作过程中遇到的小问题：如何本地化 BootStrapper，解决方案可以参考：[Creating localized WIX 3.6 bootstrappers](https://stackoverflow.com/questions/11250597/creating-localized-wix-3-6-bootstrappers)。

整个安装程序用了两天半的时间才弄好，只能说我确实是比较菜了。不过还是记录一下学习的过程吧，好歹也是一个小技能，以前也总是好奇这些东西都是用什么做的，现在已经不再是一个迷了。具体怎么使用WiX还是等什么时候有兴趣了再写吧，毕竟按上面的流程去寻找答案，最基本的需求都能够得到解决。

<div class="text-divider"></div>

# 2017-12-7 Troubleshooting

一个小问题：在使用 ExePackage 元素安装依赖时一般会先进行 RegistrySearch/DirectorySearch/FileSearch。ExePackage 的 DetectCondition 属性会使用上述三个 Serach 的属性 variable 来获取查询结果。一开始的时候，我的 RegistrySearch 写在了 ExePackage 的后面，于是无论怎么修改 DetectCondition， validate 的结果都是 false，这个问题困扰了我很久，直到我看过了这个讨论帖：[wix installer 3.7 bootstrapper Registry search](https://stackoverflow.com/questions/15219118/wix-installer-3-7-bootstrapper-registry-search)。

这个帖子给了我启发，是否因为 variable 尚未定义就被使用导致了 DetectCondition 一直是 false 呢？于是我尝试着按照这个帖子中的格式修改了我的 WiX Bundle 代码，于是 RegistrySearch 的结果就被正确识别了出来。

写C#多了以后，有时就就会有这种问题，C#中变量定义在类的哪个位置都无所谓，反正最后编译的时候编译器是可以找到的。然而对于大多数语言来讲，还是要在使用变量之前先定义好（不是编译器层面上的先定义好，是写代码时就提前写好），这是一个好习惯也是编译器实际上的要求，多加注意。