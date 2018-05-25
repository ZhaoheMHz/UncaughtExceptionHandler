//
//  UncaughtExceptionHandler.h
//  NSExceptionHandler
//
//  Created by 赵赫 on 2018/5/24.
//  Copyright © 2018年 赵赫. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UncaughtExceptionHandler : NSObject

@end


// Swift中调用请看这里的解决办法 https://stackoverflow.com/questions/25441302/how-should-i-use-nssetuncaughtexceptionhandler-in-swift/31770435#31770435
void InstallUncaughtExceptionHandler(void);
