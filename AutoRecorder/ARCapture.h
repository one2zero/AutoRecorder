//
//  ARCapture.h
//  AutoRecorder
//
//  Created by sunjianwen on 2017/4/25.
//  Copyright © 2017年 sunjianwen. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    ARCaptureRecordTypeFile,//AVCaptureMovieFileOutput 文件类型录制，整段录制，过程中无法对每帧数据进行获取和处理
    ARCaptureRecordTypeData,//AVCaptureAudioDataOutput 数据类型录制，帧数据合成录制，只对Audio数据进行合成，丢弃音频数据
} ARCaptureRecordType;

@interface ARCapture : NSObject

-(void)startRecordWithUuid:(NSString *)uuid type:(ARCaptureRecordType)type;

-(void)stop;
@end
