---
layout: post
categories: blog
share: true
comments: true
title: 'Prism MVVM 集成测试个人经验（2017.12.5 更新）'
date: '2017-11-16T21:00:00'
modified: '2017-12-05T21:30:00'
tags: [Blog, C#, Prism 5.0, MVVM, Integration Test]
author: Old Jack
hidelogo: true
---
最近被要求给项目写一个集成测试工具，项目是一个基于 Prism 5.0、UnityContainer 的 WPF 项目。在网上查找了 MVVM 和 Prism 框架集成测试的资料后，并没有什么有效的解决方案。

最相近的一篇帖子是：[WPF Application - MVVM - Integration Testing - Automation Beneath UI Layer](https://social.msdn.microsoft.com/Forums/en-US/41bbf023-8e5c-4547-a8f7-116acf2cf2f2/wpf-application-mvvm-integration-testing-automation-beneath-ui-layer?forum=vststest)，但是也没有什么建设性的结果。

经过对 Prism framework、UnityContainer framework 以及整个项目架构的研究，获得了如下的思路：MVVM 模式的业务逻辑均在 ViewModel 中实现，同时 Prism framework 是以 Module 为基础，所以集成测试所要进行的组合各模块的测试就变成了组合各 ViewModel 的测试。

设计和实现过程中遇到的主要问题有下：

1. Module 初始化时用 IUnityContainer 注册了太多的 service 实例（service 实现了某些接口），即 module 初始化部分被写死，无对外接口。

    - 解决方案1：写一个通用注册方法。难度较大，需要先利用反射读取 ViewModel 的构造函数参数，然后利用 container 或者利用C#的反射构造 service 实例；
    - 解决方案2：手动 copy 各 module 注册 service 的代码，在 IntegrationTest module 中注册所有的 service。这么做会浪费一些内存，而且随着以后模块的增加，需要注册的 service 将越来越多，注册代码会越来越长；但这是目前能想出的最简单的解决方案，也是当前采用的解决方案；
    - 解决方案3：在加载所有 Module 后可不注册任何 service。但这会启动所有的功能模块和界面，而且会给事件响应带来潜在的页面转换或者其他问题。

2. ViewModel 初始化，ViewModel 成员改变，ViewModel 成员断言（Assert，写过单元测试的都会熟悉这个词），事件参数验证。

    - ViewModel 初始化：因为现在采用注册所有 service 的方法初始化，所以可以用 IUnityContainer 解决 ViewModel 的实例；
    - ViewModel 成员改变：ViewModel 的结构各异，写一个通用的成员改变方法难度较大，尤其是涉及到泛型类型的成员时，即使用 IUnityContainer 仍需要事先做一系列的 type mapping；
    - ViewModel 成员断言：可以利用反射实现通用的成员断言方法，但泛型类仍是比较难处理的部分，目前只实现了 IList 类型泛型的断言， IDictionary 类型还未实现；
    - 事件参数验证：因为WPF应用和服务器进行通信，需要验证从服务器拿回来的数据是否正确。而针对每一种事件，都需要写断言其成员正确性的方法。

3. 测试用例 .xml 文件结构。

    - 集成测试虽然是开发人员的工作，但是过于复杂的测试用例配置文件会降低集成测试的效率；
    - 当 ViewModel 内部结构变化，或者事件的参数变化时，需要保证旧的测试用例配置文件还能够继续运行，或者只需要做出少量更改就可以继续进行测试；
    - 尽可能保持和内部流程的一致性，使开发人员或测试人员能够快速地上手编写测试用例配置文件。

基于以上的问题，现在集成测试工具的结构大概如下：

- IntegrationTest Module：基于 Prism framework 的 Module，生成后得到一个动态链接库（.dll），只需放到项目根目录下，改变一下 ModuleCatalog 文件即可启用集成测试功能；
- IntegrationTestView & IntegrationTestVM：集成测试的 View 和 ViewModel；
- TestCase Class：测试用例类，解析.xml配置文件，实现 function flow，事件参数验证和 Assert（个人觉得有些耦合过紧，需要重构代码）；
- IVMInitializeService、IVMMemberChangeService、IAssertService、IEventParaValidteService Interface：用来实现上述功能；
- 具体实现以上接口的 Service 实体 Class；

现在这个工具的基本测试功能已经实现，目前存在着这样的一些问题：

1. 测试用例运行慢。或许和需要解析 .xml 文件有关，也或许和 TestCase 类的实现有关，以后会深入研究瓶颈所在；

2. 因为有审计系统，和后端通信前必须进行 authentication，所以测试工具必须以一个业务功能集成在项目当中，测试工具较重；

3. TestCase 耦合度较高，再加上一个问题，至今都没有对 TestCase 类编写任何单元测试，不利于代码重构和阅读。

我不敢说我对于集成测试的理解是正确的，或者说我们团队对于集成测试的理解是正确的，因为这也是最近才刚刚提出的需求：更完善的软件开发流程。同时关于集成测试所需要做的事情，也有着不同的定义，所以以上的流程和实现，只是我们集成测试工具编写组针对这个项目的思路，不一定是最佳的实现思路。欢迎大家沟通交流。

<div class="text-divider"></div>

# 2017-11-21 问题解决：

#### 1. 测试用例慢的原因是反射的使用不合理。

其中有一个扩展方法是：

```csharp
private Type FindTypeInCurrentAppDomain(this string type)
{
    try
    {
        return AppDomain.CurrentDomain.GetAssemblies()
        .SelectMany(a => a.GetTypes(), (a,t) => t)
        .FirstOrDefault(t => t.FullName.Contains(type));
    }
    catch(System.Reflection.ReflectionTypeLoadException)
    {
        return null;
    }
}
```

这个扩展方法被使用了太多次，而这是段非常低效的代码，应该有针对性地在某个或某些程序集中查找相应的 Type。因此采用了另外的两个扩展方法替换该扩展方法：

```csharp
private Type FindTypeInABCAssembly(this string type)
{
    try
    {
        return AppDomain.CurrentDomain.GetAssemblies()
            .Where(a => a.FullName.Contains("ABC"))
            .SelectMany(a => a.GetTypes(), (a,t) => t)
            .FirstOrDefault(t => t.FullName.Contains(type));
    }
    catch(System.Reflection.ReflectionTypeLoadException)
    {
        return null;
    }
}
```

```csharp
private Type FindTypeInSpecificAssembly(this string type, string assemblyName)
{
    try
    {
        return AppDomain.CurrentDomain.Load(assemblyName)
            .FirstOrDefault(t => t.FullName.Contains(type));
    }
    catch(System.Reflection.ReflectionTypeLoadException)
    {
        return null;
    }
}
```

FindTypeInABCAssembly 函数：在名字中含有“ABC”的程序集中查找该 Type；FindTypeInSpecificAssembly：在一个指定的程序集中查找该 Type。另外在其它的地方进行了一些其他优化，删除冗余的变量，删除冗余的逻辑代码。

在进行了优化后，每一个测试用例的运行时间从1.3s - 1.5s缩减到了0.1s - 0.16s，同时内存的使用量也减少了很多。

#### 2. TestCase logging 优化。

主要是改变了一些记录 log 的细节，增加了一些字段。

<div class="text-divider"></div>

速度和内存的问题解决后，主要的问题就是实际使用的效果如何，其次是样式的修改和跟进需求。现在只对两个 ViewModel 在工具开发过程中进行了测试，其他的 ViewModel 还未进行测试，扩展性和稳定性还有待实战检验。

<div class="text-divider"></div>

# 2017-11-24 新问题发现

之前一直在处理测试用例的解析和性能问题，但是对整体架构和断言部分的代码却有些忽视了（内部服务器审计功能未开启，无法返回要断言的数据）。最严重的问题就是有一个模块的 ViewModel 和 Model 融合在了一起（如果我对 MVVM 模式没有理解错）。该 ViewModel 使用一个后台线程用轮询的方式从服务器不断获取数据，同时在另一个后台线程中对数据进行统计处理，最后将结果通过数据绑定的形式绑定到 View 上。该 ViewModel 的多线程代码并没有使用 async/await 异步模式，也没有使用基于事件的异步模式，所以无法得知是否已经从服务器获取到数据，或统计处理是否结束。即这一 ViewModel 本身就是不可测试的，这一点在我给统计处理功能写单元测试是就有所感觉。

这个问题短时间内可能无法解决，因为内部测试服务器上暂时还没有数据可以用来检验这段代码的正确性，所以没有办法对此进行改进。即使有数据可以用来检验，那个模块的结构可能也不能轻易改变。更何况其他模块的情况可能还各不相同，所以想要设计出一个高度抽象的测试架构还是有难度的，这可能需要通过对每个模块的设计模式进行规定的方式进行改进，而这是一个大工程。

听老员工们和组会的说法，每个模块是由不同的负责人负责的，所以每个模块的结构和模式都不尽相同，这给测试工作增加了很大的难度。我不知道对每个模块的设计模式都给出规定是否会让应用结构过于死板，但是这是让各模块可以进行集成测试提供了可能性。

<div class="text-divider"></div>

这个集成测试工具可能会暂时告一段落，以后会不会用得上我也说不准。但是凭借这个机会，我增加了对整个项目结构的理解，增加了对 Prism、UnityContainer、WPF、设计模式的理解，所以收获还是很大的。希望以后能够总结出一个可以进行集成测试的设计模式，然后尝试着在所有的模块中采用这个设计模式，甚至推广到 Prism 框架中，方便进行集成测试。

<div class="text-divider"></div>

# 2017-12-5 进展更新

前两天测试组来看了我写的这个工具，虽然距离成型还有很远的距离，但是这表明或许以后真的会用这个东西，所以这两天着手开始试着进行部署、测试、第二轮优化和重构。

因为 Team Foudation Version Control 没有权限或者其他的什么原因，我没有权限创建当前项目的分支，所以这个集成测试工具和项目是分开的两个项目。因此本来的设计是打算集成测试模块写好后，把.dll文件和其他的几个配置文件拷到应用目录下，然后就能屏蔽掉UI层进行集成测试，但是反射部分的代码出现了一些问题，就是上面写到的那几个FindTypeIn函数，会抛出 ReflectionLoadTypeExecption 异常。所以为了解决这个问题，选择了使用 UnityContainer 进行重构。

项目本身是基于 Prism 框架的，Prism 是一个基于 Module 进行开发的框架，在每一个 Module Initialize 的时候会进行 Business & UI 的依赖注入和事件发布订阅。如果不测试UI的话，那么只调用 Business 的依赖注入和事件发布订阅方法就可以达到目的了。但是 Module 只暴露了 Initialize 这一个方法，暴露其他方法的可能性不大，短期内也不太可能会增加新的接口来方便测试，所以目前的解决方案就是为每一个 Module 构造一个只包含 Business 依赖注入和事件订阅发布的“子集”——“Fake Module”。

这么做个人认为有如下的几个好处：
1. **集成测试模块彻底符合 Prism 框架的结构**。以前集成测试模块中还会直接引用其他模块的代码，现在已经彻底相互独立。当然如果以后可以调用其他模块的依赖注入和事件发布订阅方法，是不需要 Fake Module 的测试；
2. **开发人员更容易为集成测试模块编写测试代码**。因为无法调用 Module 的依赖注入和事件发布订阅方法，需要手动拷贝代码实现，以前的模式会把所有的依赖注入和事件发布订阅都放在集成测试 Module 的 Initialize 方法中，同时会在集成测试模块里给 View Model 写服务，结构混乱。现在用了 Fake Module 模式只需要在模块对应的 Fake Module 中编写测试代码即可，结构清晰，思路也和正常的 Prism Module 开发一致；
3. **可以通过配置文件控制要测试哪些 Module**。以前因为代码写死了，会把所有 Module 的依赖注入和事件发布订阅都加载进来，现在可以通过配置文件进行配置有选择性地进行加载。

现在还有几个小问题我认为或许还有改进的空间：
1. **被测试的 Command 对应的方法尽量不要有参数**。有些 Command 对应的方法会使用一些 string 类型甚至 object 类型的参数，这些参数从哪里来的我还没去 View 层看，不过我猜测很有可能是 View 层绑定的什么的东西，在 Business 和 UI 分离这方面可能还有些不够好；
2. **多线程和异步代码结束时没有通知机制**。这个部分现在还没接触到，但是如果要验证结果的话，早晚会涉及这里。这个部分大多是用的还是 Thread 轮询的方式，而不是 Task 的 Future，不知道应该何时对结果进行验证。
3. **Console Application**。测试组提过希望在命令行里运行，能否实现现在存疑，Prism 相关的逻辑或许可以在Console Application里实现（需要调研），另外 Authenticate 部分目前是绕不过去的，这部分的代码也不知道能否移植到 Console Application 中去。目前能做到的只有用 log4net 输出格式化的日志。

当然疑虑也是存在的：这么做是否是正确的？持续集成中是否还需要集成测试这一环节？是否有更好的解决方案？三问三不知，希望以后能自己找到答案。