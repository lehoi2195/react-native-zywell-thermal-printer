//
//  PosWIFIManager.m
//  Printer
//
//  Created by apple on 16/4/5.
//  Copyright © 2016年 Admin. All rights reserved.
//

#import "POSWIFIManager.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <SystemConfiguration/CaptiveNetwork.h>

static POSWIFIManager *shareManager = nil;

@interface POSWIFIManager ()<GCDAsyncSocketDelegate>
@property (nonatomic,strong) GCDAsyncSocket *sendSocket;
@property (nonatomic,strong) NSTimer *connectTimer;
@end

@implementation POSWIFIManager

/// Create WiFi management object
+ (instancetype)shareWifiManager {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    shareManager = [[POSWIFIManager alloc] init];
  });
  return shareManager;
}

- (instancetype)init {
  if (self = [super init]) {
    _sendSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    _sendSocket.userData = @(SocketOfflineByUser);
    _commandBuffer=[[NSMutableArray alloc]init];
  }
  return self;
}

 /** Disconnect manually */
- (void)POSDisConnect {

    if (_sendSocket) {
        _sendSocket.userData = @(SocketOfflineByUser);
        _isAutoDisconnect = NO;
        [self.connectTimer invalidate];
        [_sendSocket disconnect];
    }
}

/// send data
/// @param data data
-(void)POSWriteCommandWithData:(NSData *)data{
    if (_connectOK) {
        if (commandSendMode==0){
            [_sendSocket writeData:data withTimeout:-1 tag:0];

        }
        else
            [_commandBuffer addObject: data];
        //[_sendSocket writeData:data withTimeout:-1 tag:0];
    }


}

/// Send data and call back
/// @param data data
/// @param block callback
-(void)POSWriteCommandWithData:(NSData *)data withResponse:(POSWIFICallBackBlock)block{

    if (_connectOK) {
        self.callBackBlock = block;
        if (commandSendMode==0)
            [_sendSocket writeData:data withTimeout:-1 tag:0];
        else
            [_commandBuffer addObject: data];
    }

}


///Send instruction method with Callback, recommended
/// @param data Data sent
-(void)POSWriteDataWithCallback:(NSData *)data completion:(void (^)(BOOL success))completion{
    if (_connectOK) {
        if (commandSendMode==0){
            [_sendSocket writeData:data withTimeout:-1 tag:0];
            if (completion) {
                completion(YES);
            }

        }
        else{
            [_commandBuffer addObject: data];
            if (completion) {
                completion(YES);
            }
        }
    }
}


/**
send messages
 @param str data
 */
- (void)POSSendMSGWith:(NSString *)str {
    if (_connectOK) {
        str = [str stringByAppendingString:@"\r\n"];
        NSData *data = [str dataUsingEncoding:NSASCIIStringEncoding];
        NSLog(@"%@==%@",str,data);
        if (commandSendMode==0)
       [_sendSocket writeData:data withTimeout:-1 tag:0];
        else
        [_commandBuffer addObject: data];

    }
}

/// Connect the printer
/// @param hostStr Printer ip address
/// @param port port of printer
/// @param block callback
-(void)POSConnectWithHost:(NSString *)hostStr port:(UInt16)port completion:(POSWIFIBlock)block
{
    _connectOK = NO;
    _hostStr = hostStr;
    _port = port;

    NSError *error=nil;
    _connectOK=[self.sendSocket connectToHost:hostStr onPort:port withTimeout:3 error:&error];
    block(_connectOK);
}

/// Connection established
/// @param sock sock object
/// @param host Host address
/// @param port The port number
- (void)onSocket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"%s host=%@  port = %d", __FUNCTION__, host,port);
    if ([self.delegate respondsToSelector:@selector(POSWIFIManager:didConnectedToHost:port:)]) {
        [self.delegate POSWIFIManager:self didConnectedToHost:host port:port];
    }

    [_sendSocket readDataWithTimeout: -1 tag: 0];
}

- (void)longConnectToSocket {
    // 根据服务器要求发送固定格式的数据，假设为指令@"longConnect"，但是一般不会是这么简单的指令

    NSString *longConnect = @"longConnect";
    NSData   *dataStream  = [longConnect dataUsingEncoding:NSUTF8StringEncoding];


}

/**
 写数据
 */
- (void)onSocket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    NSLog(@"%s %d, tag = %ld", __FUNCTION__, __LINE__, tag);
    if ([self.delegate respondsToSelector:@selector(POSWIFIManager:didWriteDataWithTag:)]) {
        [self.delegate POSWIFIManager:self didWriteDataWithTag:tag];
    }
    [_sendSocket readDataWithTimeout: -1 tag: 0];
}

// 遇到错误关闭连接
- (void)onSocket:(GCDAsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    _isAutoDisconnect = YES;
    if ([self.delegate respondsToSelector:@selector(POSWIFIManager:willDisconnectWithError:)]) {
        [self.delegate POSWIFIManager:self willDisconnectWithError:err];
    }
    NSLog(@"%s %d, tag = %@", __FUNCTION__, __LINE__, err);
}

// 读取数据 这里必须要使用流式数据
- (void)onSocket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{

    NSString *msg = [[NSString alloc] initWithData: data encoding:NSUTF8StringEncoding];

    if ([self.delegate respondsToSelector:@selector(POSWIFIManager:didReadData:tag:)]) {
        [self.delegate POSWIFIManager:self didReadData:data tag:tag];
    }
    self.callBackBlock(data);
    NSLog(@"%s %d, ==读取到从服务端返回的内容=== %@", __FUNCTION__, __LINE__, msg);

    [_sendSocket readDataWithTimeout: -1 tag: 0];
}

// 断开连接后执行
- (void)onSocketDidDisconnect:(GCDAsyncSocket *)sock
{
    NSLog(@"%s %d", __FUNCTION__, __LINE__);
    _connectOK = NO;
    if ([self.delegate respondsToSelector:@selector(POSWIFIManagerDidDisconnected:)]) {
        [self.delegate POSWIFIManagerDidDisconnected:self];
    }
    if (sock.userData == SocketOfflineByServer) {
        _isAutoDisconnect = YES;
        // 重连

        [self POSConnectWithHost:_hostStr port:_port completion:^(BOOL isConnect) {

        }];
    }else if (sock.userData == SocketOfflineByUser) {
        _isAutoDisconnect = NO;
        return;
    }

}

- (void)showAlert:(NSString *)str {
    UIAlertView *alter = [[UIAlertView alloc] initWithTitle:@"提示" message:str delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alter show];
}

-(NSArray*)POSGetBuffer
{
    return [_commandBuffer copy];
}

-(void)POSClearBuffer
{
    [_commandBuffer removeAllObjects];
}

-(void)sendCommand:(NSData *)data
{
    [_sendSocket writeData:data withTimeout:-1 tag:0];
}

-(void)POSSendCommandBuffer
{
    float timeInterver=0.5;

    for (int t=0;t<[_commandBuffer count];t++)
    {
        //[self performSelectorOnMainThread:@selector(sendCommand:) withObject:_commandBuffer[t] waitUntilDone:NO ];
        [self performSelector:@selector(sendCommand:) withObject:_commandBuffer[t] afterDelay:timeInterver];
        timeInterver=timeInterver+0.2;
    }
    [_commandBuffer removeAllObjects];
}

- (void)POSSetCommandMode:(BOOL)Mode{
    commandSendMode=Mode;
}


@end
