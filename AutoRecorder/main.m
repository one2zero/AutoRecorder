//
//  main.m
//  AutoRecorder
//
//  Created by sunjianwen on 2017/4/25.
//  Copyright © 2017年 sunjianwen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ARCapture.h"

#define Auto_Recorder_Cmd_Description    @"\n Usage: AutoRecorder [-u] [-t]<optional>  \n  -u device uuid \n  -t<optional> redord type[0/1] 0:file 1:data by per frame\n"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello AutoRecorder!");
        
        
        NSArray *arguments = NSProcessInfo.processInfo.arguments;
        NSInteger argCount = arguments.count;
        
        NSString *uuid;
        NSString *type;
        
        NSInteger uIndex = [arguments indexOfObject:@"-u"];
        if ( uIndex>0 && argCount>uIndex) {
            uuid = arguments[uIndex+1];
        }else{
            NSLog(Auto_Recorder_Cmd_Description);
        }
        
        NSInteger tIndex = [arguments indexOfObject:@"-t"];
        if ( tIndex>0 && argCount>tIndex) {
            type = arguments[tIndex+1];
        }
        
        ARCapture *cap = [[ARCapture alloc] init];
        [cap startRecordWithUuid:uuid type:[type integerValue]];
    }
    return 0;
}
