//
//  ARCapture.m
//  AutoRecorder
//
//  Created by sunjianwen on 2017/4/25.
//  Copyright © 2017年 sunjianwen. All rights reserved.
//

#import "ARCapture.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMediaIO/CMIOHardwareObject.h>
#import <CoreMediaIO/CMIOHardwareSystem.h>
#import <AppKit/AppKit.h>

#import "RoutingConnection.h"
#import "RoutingHTTPServer.h"


@interface ARCapture()<AVCaptureFileOutputRecordingDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>{
    AVCaptureSession *_session;
    AVCaptureDevice *_selectedDevice;
    AVCaptureDeviceInput *_input;
    NSArray *_devices;
    
    
    AVCaptureMovieFileOutput *_fileOutput;
    
    AVCaptureVideoDataOutput *_dataOutput;
    AVAssetWriter *_assetWriter;
    AVAssetWriterInput *_videoInput;
    
    BOOL needRecord;
    int frameCount;
    
    RoutingHTTPServer *_server;
}

@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic) ARCaptureRecordType type;

@end

@implementation ARCapture

-(instancetype)init{
    self = [super init];
    
    if (self) {
        
        _session = [[AVCaptureSession alloc] init];
        _session.sessionPreset = AVCaptureSessionPresetLow;
        
        
        CMIOObjectPropertyAddress prop = {kCMIOHardwarePropertyAllowScreenCaptureDevices,kCMIOObjectPropertyScopeGlobal,kCMIOObjectPropertyElementMaster};
        UInt32 allow = 1;
        CMIOObjectSetPropertyData(kCMIOObjectSystemObject, &prop, 0, nil, sizeof(allow), &allow);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(devicesConnected:) name:AVCaptureDeviceWasConnectedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(devicesDidChange:) name:AVCaptureDeviceWasDisconnectedNotification object:nil];
    }
    
    return self;
}


#pragma mark ----Device selection

- (void)devicesConnected:(NSNotification *)notification
{
    NSLog(@"Device connected...");
    [self refreshDevices];
    
}
- (void)devicesDidChange:(NSNotification *)notification
{
    NSLog(@"Device disconnected...");
    
    [self refreshDevices];
}

-(void)refreshDevices{
    _devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeMuxed];
    for (AVCaptureDevice *device in  _devices) {
        
//        CMFormatDescriptionRef formatDes = device.activeFormat.formatDescription;
//        CGRect size = CMVideoFormatDescriptionGetCleanAperture(formatDes,true);
        NSLog(@"Device with uuid :%@",device.uniqueID);
        if ([_uuid isEqualToString:device.uniqueID]) {
            [self setSelectedCaptureDevice:device];
            return;
        }
    }
}

-(void)setSelectedCaptureDevice:(AVCaptureDevice *)device{
    _selectedDevice = device;
   
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_selectedDevice error:nil];
    if ([_session canAddInput:_input]) {
        [_session addInput:_input];
    }
    
    //视频输出的配置，暂时写死，未做动态获取或者入参的配置
    CGSize _viewSize =  CGSizeMake(750, 1334);
    int _scale = 1;
    NSDictionary* videoSettings = @{AVVideoCodecKey: AVVideoCodecH264,
                                    AVVideoWidthKey: [NSNumber numberWithInt:_viewSize.width*_scale],
                                    AVVideoHeightKey: [NSNumber numberWithInt:_viewSize.height*_scale]};
    
    if (self.type == ARCaptureRecordTypeData) {
        _dataOutput = [[AVCaptureVideoDataOutput alloc] init];
        dispatch_queue_t queue = dispatch_queue_create("VideoQueue", DISPATCH_QUEUE_SERIAL);
        [_dataOutput setSampleBufferDelegate:self queue:queue];
        
        _dataOutput.videoSettings = videoSettings;
        if ([_session canAddOutput:_dataOutput]) {
            [_session addOutput:_dataOutput];
        }
    }else{
        _fileOutput = [[AVCaptureMovieFileOutput alloc] init];
        if ([_session canAddOutput:_fileOutput]) {
            [_session addOutput:_fileOutput];
            [_fileOutput setOutputSettings:videoSettings forConnection:_fileOutput.connections[0]];
        }
    }
    
    [_session startRunning];
    NSLog(@"Sesstion starting...");

}



#pragma mark ----Core
-(void)startRecordWithUuid:(NSString *)uuid  type:(ARCaptureRecordType)type{
    self.uuid = uuid;
    self.type = type;
    
    [self startServing];
    
    [self refreshDevices];
    NSLog(@"Waiting device...");
    CFRunLoopRun();
    
}

-(void)stop{
    NSLog(@"Stoped");
    [self stopServing];
    [_session stopRunning];
    CFRunLoopStop(CFRunLoopGetMain());
}

//- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
//    
//}
//
//- (void)captureOutput:(AVCaptureFileOutput *)captureOutput willFinishRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections error:(NSError *)error{
//    
//}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    
    NSLog(@"Recorded:\n%llu Bytes\n%@ Duration", [captureOutput recordedFileSize], [self timeStringFromCMTime:captureOutput.recordedDuration]);
    
    if(_filePath){
        NSURL *fileUrl = [NSURL fileURLWithPath:_filePath isDirectory:NO relativeToURL:nil];
        [[NSFileManager defaultManager] removeItemAtURL:fileUrl error:nil]; // attempt to remove file at the desired save location before moving the recorded file to that location
        if ([[NSFileManager defaultManager] copyItemAtURL:outputFileURL toURL:fileUrl error:&error]){
            NSLog(@"Save sucess at path: %@",fileUrl);
        }else{
            NSLog(@"Save fail with error: %@",error);
        }
        
    }
}

-(NSString *)timeStringFromCMTime:(CMTime)time{
    return [NSString stringWithFormat:@"%lld",time.value/time.timescale];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
    if (needRecord) {
        if (frameCount<1) {
            CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            NSLog(@"Start at value: %lld timescale:%d",pts.value,pts.timescale);
            [_assetWriter startSessionAtSourceTime:pts];
        }else{
            AVAssetWriterStatus status = _assetWriter.status;
            NSError *error =  _assetWriter.error;
            if ([_videoInput isReadyForMoreMediaData] && status == AVAssetWriterStatusWriting && !error) {
                BOOL success = [_videoInput appendSampleBuffer:sampleBuffer];
                if (success) {
                    //                NSLog(@"appendSampleBuffer sucess");
                }else{
                    NSLog(@"AppendSampleBuffer fail.");
                }
            }else{
                NSLog(@"AVAssetWriter not ready for wright,status:%ld error:%@.",(long)status,error);
            }
        }
        frameCount++;
    }
    
    
}

-(void)beginRecording:(NSString *)filePath{
    _filePath = filePath;
    
    if (self.type == ARCaptureRecordTypeData) {
        NSURL *localOutputURL = [NSURL fileURLWithPath:filePath isDirectory:NO relativeToURL:nil];
        [[NSFileManager defaultManager] removeItemAtURL:localOutputURL error:nil];
        NSError *localError;
        _assetWriter = [[AVAssetWriter alloc] initWithURL:localOutputURL
                                                fileType:AVFileTypeQuickTimeMovie error:&localError];
        
        if (localError) {
            NSLog(@"AVAssetWriter init error:%@",localError);
        }
        // Setup video track to write video samples into
        _videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:
                      AVMediaTypeVideo outputSettings:nil];
        
        [_assetWriter addInput:_videoInput];
        
        [_assetWriter startWriting];
        
        needRecord = YES;
    }else{
        char *tempNameBytes = tempnam([NSTemporaryDirectory() fileSystemRepresentation], "AutoRecorder_");
        NSString *tempName = [[NSString alloc] initWithBytesNoCopy:tempNameBytes length:strlen(tempNameBytes) encoding:NSUTF8StringEncoding freeWhenDone:YES];
        
        [_fileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:[tempName stringByAppendingPathExtension:@"mov"]] recordingDelegate:self];
    }
    
    
    NSLog(@"beginRecording");
}

-(void)completeRecording{
    if (self.type == ARCaptureRecordTypeData) {
        needRecord = NO;
        frameCount = 0;
        
        [_videoInput markAsFinished];
        [_assetWriter finishWritingWithCompletionHandler:^{
            NSLog(@"completeRecording");
        }];
    }else{
        [_fileOutput stopRecording];
        NSLog(@"completeRecording");
    }
}



#pragma mark ---- HTTP Server

- (void)startServing
{
    [self startHTTPServer];
}

-(void)stopServing{
    [_server stop];
}

- (void)startHTTPServer
{
    _server = [[RoutingHTTPServer alloc] init];
    NSString *serverHeader = @"ARHttpServer";
    [_server setDefaultHeader:@"Server" value:serverHeader];
    
    [self setupRoutes];
    [_server setPort:9000];
    [_server setDocumentRoot:[@"~/Sites" stringByExpandingTildeInPath]];
    
    NSError *error;
    if (![_server start:&error]) {
        NSLog(@"Error starting HTTP server: %@", error);
    }else{
        NSLog(@"Sucess starting HTTP server: %d", _server.port);
    }
}

- (void)setupRoutes {
    __block ARCapture *this = self;
    [_server get:@"/stop" withBlock:^(RouteRequest *request, RouteResponse *response) {
        
        [response respondWithString:@"stoping!"];
        
        [this completeRecording];
    }];
    
    [_server post:@"/start" withBlock:^(RouteRequest *request, RouteResponse *response) {
//        [response respondWithData:[request body]];
        
        NSString *body = [[NSString alloc] initWithData:request.body encoding:NSUTF8StringEncoding];
        NSString *respondString = [NSString stringWithFormat:@"start! %@",body];
        [response respondWithString:respondString];
        
        [this beginRecording:body];
    }];
}


@end
