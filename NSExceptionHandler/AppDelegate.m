//
//  AppDelegate.m
//  NSExceptionHandler
//
//  Created by 赵赫 on 2018/5/24.
//  Copyright © 2018年 赵赫. All rights reserved.
//

#import "AppDelegate.h"
#import "UncaughtExceptionHandler.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
//    NSSetUncaughtExceptionHandler(&UncaughtExceptionHandler);
    InstallUncaughtExceptionHandler();
    
    return YES;
}


@end
