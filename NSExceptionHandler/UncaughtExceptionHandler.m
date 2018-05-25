//
//  UncaughtExceptionHandler.m
//  NSExceptionHandler
//
//  Created by 赵赫 on 2018/5/24.
//  Copyright © 2018年 赵赫. All rights reserved.
//

#import "UncaughtExceptionHandler.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>
#import <UIKit/UIKit.h>

//signal信号名
NSString *const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
NSString *const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
NSString *const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";

volatile int32_t UncaughtExceptionCount = 0;
const int32_t UncaughtExceptionMaximum = 10;    // 表示最多只截获10次异常，如果超过十次则不截获弹出alter了直接崩溃

const NSInteger UncaughtExceptionHandlerSkipAddressCount = 4;
const NSInteger UncaughtExceptionHandlerReportAddressCount = 5;

@interface UncaughtExceptionHandler ()

@property (nonatomic, strong) NSNumber *dimissed;

@end

@implementation UncaughtExceptionHandler {
}

// 获取调用堆栈
+ (NSArray *)backtrace {
    // 指针列表
    void *callstack[128];
    
    // backtrace用来获取当前线程的调用堆栈，获取的信息存放在这里的callstack中
    // 128用来指定当前的buffer中可以保存多少个void*元素
    // 返回值是实际获取的指针个数
    int frames = backtrace(callstack, 128);
    
    // backtrace_symbols将从backtrace函数获取的信息转化为一个字符串数组
    // 返回一个指向字符串数组的指针
    // 每个字符串包含了一个相对于callstack中对应元素的可打印信息，包括函数名、偏移地址、实际返回地址
    char **strs = backtrace_symbols(callstack, frames);
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (i = UncaughtExceptionHandlerSkipAddressCount; i <UncaughtExceptionHandlerSkipAddressCount +UncaughtExceptionHandlerReportAddressCount; i++){
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);     // C中的类型记得free
    return backtrace;
}

- (void)handleAnException:(NSException *)exception {
    self.dimissed = @(NO);
    
    // 做一些崩溃前的处理（比如弹个窗啥的）
    [self validateAndSaveCriticalApplicationDataWithException:exception];
    
    
    
    
    // Runloop会在这里一直运行，当dimissed设置YES后，下面的代码才会运行（但dimissed修改为YES这一操作并没有生效！）
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);

    while (![self.dimissed integerValue]) {
        for (NSString *mode in (__bridge NSArray *)allModes) {
            // 为阻止线程退出，使用 CFRunLoopRunInMode(model, 0.001, false)等待系统消息，false表示RunLoop没有超时时间
            CFRunLoopRunInMode((CFStringRef)mode,0.001, false);
        }
    }
    
    
    
    // 当dimissed设置为YES，上面的Runloop才会停止，代码走到这里（但dimissed的修改并没有生效？？？为什么呢）
    CFRelease(allModes);
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT,SIG_DFL);
    signal(SIGILL,SIG_DFL);
    signal(SIGSEGV,SIG_DFL);
    signal(SIGFPE,SIG_DFL);
    signal(SIGBUS,SIG_DFL);
    signal(SIGPIPE,SIG_DFL);
    
    NSLog(@"%@",[exception name]);
    if ([[exception name] isEqual:UncaughtExceptionHandlerSignalExceptionName]) {
        kill(getpid(), [[[exception userInfo] objectForKey:UncaughtExceptionHandlerSignalKey] intValue]);
    }else{
        [exception raise];
    }
}





// 自己顶一个处理崩溃的方法，弹个alert啥的
- (void)validateAndSaveCriticalApplicationDataWithException:(NSException *)exception {
    /******************************** 展示崩溃信息 ********************************/
    NSLog(@"崩溃了");
    
    // 将Eexception的name、reason、userInfo(堆栈信息)展示出来
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"请截图发送给开发者，谢谢配合\n异常原因如下:\n%@\n%@",nil), [exception reason],[[exception userInfo] objectForKey:UncaughtExceptionHandlerAddressesKey]];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"闪退了"  message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    // 缩小message字体，保证展示尽可能多的崩溃信息
    NSMutableAttributedString *alertControllerMessageStr = [[NSMutableAttributedString alloc] initWithString:message attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:10]}];
    [alert setValue:alertControllerMessageStr forKey:@"attributedMessage"];

    __weak typeof(self) _ws = self;
    /******************************** 注意，dimissed用于标志App是否让崩溃闪退，但实际上当设置为YES后并没有生效，所以这里注释掉了 ********************************/
//    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"退出App" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            _ws.dimissed = @(YES);
//        });
//    }];
//    [alert addAction:cancelAction];
    UIAlertAction *continueAction = [UIAlertAction actionWithTitle:@"继续运行" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    }];
    [alert addAction:continueAction];

    UIViewController * rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    [rootViewController presentViewController:alert animated:NO completion:nil];
}

@end








// 截获异常信息
void HandleException(NSException *exception) {
//    //递增一个全局计数器
//    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
//
//    // 这里对崩溃次数做了限制，如果超过崩溃次数上限则直接让app崩溃了
//    if (exceptionCount > UncaughtExceptionMaximum) {
//        return;
//    }
    
    // 渠道回溯的堆栈
    NSArray *callStack = [UncaughtExceptionHandler backtrace];
    NSMutableDictionary *userInfo =[NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    // 将堆栈信息保存到userInfo中
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    
    // 封装一个新的NSException，让我们的UncaughtExceptionHandler去处理
    [[[UncaughtExceptionHandler alloc] init]performSelectorOnMainThread:@selector(handleAnException:) withObject:
     [NSException exceptionWithName:[exception name] reason:[exception reason] userInfo:userInfo] waitUntilDone:YES];
}

//截取signal信息
void SignalHandler(int signal) {
//    // 递增的一个全局计数器，很快很安全，防止并发数太大
//    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
//    if (exceptionCount >UncaughtExceptionMaximum) {
//        return;
//    }
    
    // 设置是哪一种 single 引起的问题
    NSMutableDictionary *userInfo =[NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
    
    // 获取堆栈信息数组
    NSArray *callStack = [UncaughtExceptionHandler backtrace];
    // 将堆栈信息保存到userInfo中
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    
    // 封装一个新的NSException，让我们的UncaughtExceptionHandler去处理
    [[[UncaughtExceptionHandler alloc] init]performSelectorOnMainThread:@selector(handleAnException:)withObject:[NSException exceptionWithName:UncaughtExceptionHandlerSignalExceptionName reason:[NSString stringWithFormat:NSLocalizedString(@"Signal %d was raised.",nil),signal]userInfo:
                                                                                                               [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:signal]forKey:UncaughtExceptionHandlerSignalKey]]waitUntilDone:YES];
}




void InstallUncaughtExceptionHandler(void) {
    /**************** 捕获异常 ****************/
    NSSetUncaughtExceptionHandler(&HandleException);
    
    
    
    /**************** 捕获signal ****************/
    signal(SIGHUP, SignalHandler);//本信号在用户终端连接(正常或非正常)结束时发出, 通常是在终端的控制进程结束时, 通知同一session内的各个作业
    signal(SIGINT, SignalHandler);//程序终止(interrupt)信号, 在用户键入INTR字符(通常是Ctrl-C)时发出，用于通知前台进程组终止进程。
    signal(SIGQUIT, SignalHandler);//类似于一个程序错误信号。
    
    signal(SIGABRT, SignalHandler);//调用abort函数生成的信号。
    signal(SIGILL, SignalHandler);//用来立即结束程序的运行. 本
    signal(SIGSEGV, SignalHandler);//试图访问未分配给自己的内存, 或试图往没有写权限的内存地址写数据.
    signal(SIGFPE, SignalHandler);//在发生致命的算术运算错误时发出.
    signal(SIGBUS, SignalHandler);//访问不属于自己存储空间或只读存储空间
    signal(SIGPIPE, SignalHandler);//管道破裂。
}
