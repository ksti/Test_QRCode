//
//  ScanQRCodeViewController.m
//  Test_QRCode
//
//  Created by forp on 15/12/31.
//  Copyright © 2015年 forp. All rights reserved.
//

#import "ScanQRCodeViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/CGImageProperties.h>

#import "MyQRCodeViewController.h"

#define NLSystemVersionGreaterOrEqualThan(version) ([[[UIDevice currentDevice] systemVersion] floatValue] >= version)
#define IOS7_OR_LATER NLSystemVersionGreaterOrEqualThan(7.0)
#define ScreenSize [[UIScreen mainScreen] bounds].size

@interface ScanQRCodeViewController () <AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate> {
    
    __weak IBOutlet UIView *_viewContainer;
    __weak IBOutlet UIView *_viewScan;
    __weak IBOutlet UIView *_viewMask1;
    __weak IBOutlet UIView *_viewMask2;
    __weak IBOutlet UIView *_viewMask3;
    __weak IBOutlet UIView *_viewMask4;
    
    __weak IBOutlet UIButton *_buttonAlbum;
    __weak IBOutlet UIButton *_buttonLight;
    __weak IBOutlet UIButton *_buttonMyQRCode;
    
    __weak IBOutlet UITextView *_textViewResult;
    
    BOOL _isReading;
    AVCaptureSession *_captureSession;
    AVCaptureVideoPreviewLayer *_videoPreviewLayer;
    
    BOOL isLightOn;
    AVCaptureDevice *device;
    
    //
    CGFloat pixelH;
    CGFloat pixelV;
    AVCaptureMetadataOutput *_captureMetadataOutput;
    AVCaptureVideoDataOutput *_captureVideoDataOutput;
    NSMutableArray *_mArrayBrightnessValues;
    
    //
    NSInteger num;
    BOOL upOrdown;
    NSTimer * timer;
    
    UIImageView *_line;
}

@end

@implementation ScanQRCodeViewController

- (void)dealloc {
    [self stopReading];
    [_videoPreviewLayer removeFromSuperlayer];
    _videoPreviewLayer = nil;
}

-(BOOL)shouldAutorotate
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return (toInterfaceOrientation == UIInterfaceOrientationPortrait);
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;//只支持这一个方向(正常的方向)
}

-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

- (void)viewDidAppear:(BOOL)animated {
    if (_captureSession) {
        [self startReading];
    }
    if (self.scanLineFlag) {
        [self initTimer];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    if (_captureSession) {
        [self stopReading];
    }
    if (self.scanLineFlag) {
        [self invalidateTimer];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_6_1
    if (IOS7_OR_LATER) {
        //适配7的代码，这里是在sdk7，ios7中代码
        self.navigationController.navigationBar.translucent = YES;
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.extendedLayoutIncludesOpaqueBars = YES;
    }
#endif
    [self loadDefaultSetting];
    [self loadDefaultView];
    
    //放在viewDidLayoutSubviews里，因为用到加约束了的_viewScan的frame
    //[self startReading];
    
    [self setupCaptureSession];
    [self startReading];
    
    //测试
    //[self captureStillImage];
    [self captureVideoData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    //注意，每次view改变都会调用，所以往往会调用多次
    //[self startReading];
    [self layoutVideoPreviewLayer];
    //
    [self layoutLineView];
}

#pragma mark - Load default data
- (void)loadDefaultData {
    //
}

#pragma mark - Load default Settings
- (void)loadDefaultSetting {
    //
    //AVCaptureDevice代表抽象的硬件设备
    // 找到一个合适的AVCaptureDevice
    device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (![device hasTorch]) {//判断是否有闪光灯
        //UIAlertView *alter = [[UIAlertView alloc]initWithTitle:@"提示" message:@"当前设备没有闪光灯，不能提供手电筒功能" delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:nil, nil];
        //[alter show];
        
        [self alertInViewController:self alertTitle:@"提示" message:@"当前设备没有闪光灯，不能提供手电筒功能" actionTitle:@"Cancel" actionHandler:nil otherActionTitle:nil otherActionHandler:nil];
    }
    
    isLightOn = NO;
}

#pragma mark - Load default views
- (void)loadDefaultView {
    //
    _viewMask1.backgroundColor = [UIColor colorWithRed:(40/255.0f) green:(40/255.0f) blue:(40/255.0f) alpha:1.0f];
    _viewMask1.alpha = 0.4f;
    _viewMask2.backgroundColor = [UIColor colorWithRed:(40/255.0f) green:(40/255.0f) blue:(40/255.0f) alpha:1.0f];
    _viewMask2.alpha = 0.4f;
    _viewMask3.backgroundColor = [UIColor colorWithRed:(40/255.0f) green:(40/255.0f) blue:(40/255.0f) alpha:1.0f];
    _viewMask3.alpha = 0.4f;
    _viewMask4.backgroundColor = [UIColor colorWithRed:(40/255.0f) green:(40/255.0f) blue:(40/255.0f) alpha:1.0f];
    _viewMask4.alpha = 0.4f;
    
    //
    [_buttonAlbum setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_btn_photo_nor"] forState:UIControlStateNormal];
    [_buttonLight setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_btn_flash_nor"] forState:UIControlStateNormal];
    [_buttonMyQRCode setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_btn_myqrcode_nor"] forState:UIControlStateNormal];
    
    //
    [self createScanLine];
}

- (void)createScanLine {
    //
    upOrdown = NO;
    num = 0;
    _line = [[UIImageView alloc] initWithFrame:CGRectMake(_viewScan.frame.origin.x, _viewScan.frame.origin.y, _viewScan.frame.size.width+20, 2)];
    _line.image = [UIImage imageNamed:@"line.png"];
    _line.hidden = YES;
    [self.view addSubview:_line];
}

- (void)initTimer {
    if (!timer) {
        _line.hidden = NO;
        upOrdown = NO;
        num = 0;
        timer = [NSTimer scheduledTimerWithTimeInterval:.02 target:self selector:@selector(animation1) userInfo:nil repeats:YES];
    }
}

- (void)invalidateTimer {
    _line.hidden = YES;
    [timer invalidate];
    timer = nil;
}

#pragma mark --
- (void)layoutLineView {
    [_line setFrame:CGRectMake(_viewScan.frame.origin.x, _viewScan.frame.origin.y, 220, 2)];
}

-(void)animation1
{
    if (upOrdown == NO) {
        num ++;
        _line.frame = CGRectMake(_viewScan.frame.origin.x-10, _viewScan.frame.origin.y+2*num, _viewScan.frame.size.width+20, 2);
        if (2*num == _viewScan.frame.size.height) {
            upOrdown = YES;
        }
    }
    else {
        num --;
        _line.frame = CGRectMake(_viewScan.frame.origin.x-10, _viewScan.frame.origin.y+2*num, _viewScan.frame.size.width+20, 2);
        if (num == 0) {
            upOrdown = NO;
        }
    }
    
}

#pragma mark --
- (void)setVideoDataOutput:(AVCaptureVideoDataOutput *)output {
    _captureVideoDataOutput = output;
}

- (BOOL)setupCaptureSession {
    NSError *error;
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    if (!input) {
        NSLog(@"%@", [error localizedDescription]);
        return NO;
    }
    
    _captureSession = [[AVCaptureSession alloc] init];
    // Set the input device on the capture session.
    if ([_captureSession canAddInput:input]) {
        [_captureSession addInput:input];
    }
    
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    if ([_captureSession canAddOutput:captureMetadataOutput]) {
        [_captureSession addOutput:captureMetadataOutput];
        _captureMetadataOutput = captureMetadataOutput;//
    }
    
    //代表输入图片质量大小，一般来说AVCaptureSessionPreset640x480就够使用，但是如果要保证较小的二维码图片能快速扫描，最好设置高些，如AVCaptureSessionPreset1920x1080(就是我们常说的1080p)
    //_captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
    _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    pixelH = 640.;
    pixelV = 480.;
    
    // Create a new serial dispatch queue.
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("myQueue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    
    if (self.qrcodeFlag)
        [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    else
        [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObjects:AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code, AVMetadataObjectTypeQRCode, nil]];
    
    return YES;
}

- (BOOL)setupCaptureSession2 {
    [_captureSession stopRunning];
    _captureSession = nil;
    NSError *error;
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeMetadataObject];
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    if (!input) {
        NSLog(@"%@", [error localizedDescription]);
        return NO;
    }
    
    _captureSession = [[AVCaptureSession alloc] init];
    // Set the input device on the capture session.
    if ([_captureSession canAddInput:input]) {
        [_captureSession addInput:input];
    }
    
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    if ([_captureSession canAddOutput:captureMetadataOutput]) {
        [_captureSession addOutput:captureMetadataOutput];
        _captureMetadataOutput = captureMetadataOutput;//
    }
    
    //代表输入图片质量大小，一般来说AVCaptureSessionPreset640x480就够使用，但是如果要保证较小的二维码图片能快速扫描，最好设置高些，如AVCaptureSessionPreset1920x1080(就是我们常说的1080p)
    //_captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
    _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    pixelH = 640.;
    pixelV = 480.;
    
    // Create a new serial dispatch queue.
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("myQueue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    
    if (self.qrcodeFlag)
        [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    else
        [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObjects:AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code, AVMetadataObjectTypeQRCode, nil]];
    
    return YES;
}

#pragma mark --
- (void)layoutVideoPreviewLayer {
    if (!_captureSession) {
        [self setupCaptureSession];
    }
    
    if (!_videoPreviewLayer) {
        _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    }
    [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    if (!self.fullScreenFlag) {
        _viewMask1.hidden = YES;
        _viewMask2.hidden = YES;
        _viewMask3.hidden = YES;
        _viewMask4.hidden = YES;
    } else {
        _viewMask1.hidden = NO;
        _viewMask2.hidden = NO;
        _viewMask3.hidden = NO;
        _viewMask4.hidden = NO;
    }
    if (self.fullScreenFlag) {
        [_videoPreviewLayer setFrame:self.view.layer.bounds];
        [self.view.layer insertSublayer:_videoPreviewLayer below:_viewContainer.layer];//全屏的时候适合设置captureMetadataOutput.rectOfInterest
        
        /*
         //
         //CGSize size = self.view.bounds.size;
         //CGRect cropRect = CGRectMake(40, 100, 240, 240);
         CGSize size = ScreenSize;
         CGRect cropRect = _viewScan.frame;
         CGFloat p1 = size.height/size.width;
         //CGFloat p2 = 1920./1080.;  //使用了1080p的图像输出
         CGFloat p2 = pixelH/pixelV;
         if (p1 < p2) {
         //CGFloat fixHeight = size.width * 1920. / 1080.;
         CGFloat fixHeight = size.width * pixelV / pixelH;
         CGFloat fixPadding = (fixHeight - size.height)/2;
         NSLog(@"captureMetadataOutput.rectOfInterest:--%f, %f, %f, %f",captureMetadataOutput.rectOfInterest.origin.x, captureMetadataOutput.rectOfInterest.origin.y, captureMetadataOutput.rectOfInterest.size.width, captureMetadataOutput.rectOfInterest.size.height);
         captureMetadataOutput.rectOfInterest = CGRectMake((cropRect.origin.y + fixPadding)/fixHeight, cropRect.origin.x/size.width, cropRect.size.height/fixHeight, cropRect.size.width/size.width);
         NSLog(@"captureMetadataOutput.rectOfInterest:--%f, %f, %f, %f",captureMetadataOutput.rectOfInterest.origin.x, captureMetadataOutput.rectOfInterest.origin.y, captureMetadataOutput.rectOfInterest.size.width, captureMetadataOutput.rectOfInterest.size.height);
         } else {
         //CGFloat fixWidth = size.height * 1080. / 1920.;
         CGFloat fixWidth = size.height * pixelV / pixelH;
         CGFloat fixPadding = (fixWidth - size.width)/2;
         NSLog(@"captureMetadataOutput.rectOfInterest:--%f, %f, %f, %f",captureMetadataOutput.rectOfInterest.origin.x, captureMetadataOutput.rectOfInterest.origin.y, captureMetadataOutput.rectOfInterest.size.width, captureMetadataOutput.rectOfInterest.size.height);
         captureMetadataOutput.rectOfInterest = CGRectMake(cropRect.origin.y/size.height, (cropRect.origin.x + fixPadding)/fixWidth, cropRect.size.height/size.height, cropRect.size.width/fixWidth);
         NSLog(@"captureMetadataOutput.rectOfInterest:--%f, %f, %f, %f",captureMetadataOutput.rectOfInterest.origin.x, captureMetadataOutput.rectOfInterest.origin.y, captureMetadataOutput.rectOfInterest.size.width, captureMetadataOutput.rectOfInterest.size.height);
         }
         */
        
        _captureMetadataOutput.rectOfInterest = CGRectMake(_viewScan.frame.origin.y/ScreenSize.height, _viewScan.frame.origin.x/ScreenSize.width, _viewScan.frame.size.height/ScreenSize.height, _viewScan.frame.size.width/ScreenSize.width);//(上,右,高,宽)--原点在iPhone的右上角
        NSLog(@"_viewScan.frame:--%f, %f, %f, %f",_viewScan.frame.origin.x, _viewScan.frame.origin.y, _viewScan.frame.size.width, _viewScan.frame.size.height);
        NSLog(@"captureMetadataOutput.rectOfInterest:--%f, %f, %f, %f",_captureMetadataOutput.rectOfInterest.origin.x, _captureMetadataOutput.rectOfInterest.origin.y, _captureMetadataOutput.rectOfInterest.size.width, _captureMetadataOutput.rectOfInterest.size.height);
    } else {
        [_videoPreviewLayer setFrame:_viewScan.layer.bounds];
        [_viewScan.layer insertSublayer:_videoPreviewLayer below:_viewScan.layer];
    }
}

#pragma mark --
- (BOOL)startReading {
    _isReading = YES;
    if (!_captureSession) {
        [self setupCaptureSession];
    }
    
    [self layoutVideoPreviewLayer];
    
    if (!_captureSession.running) {
        [_captureSession stopRunning];
        [_captureSession startRunning];
    }
    
    return YES;
}

-(void)stopReading{
    _isReading = NO;
    [self turnOffLed:YES];
    if (_captureSession) {
        [_captureSession stopRunning];
    }
    //[_videoPreviewLayer removeFromSuperlayer];
    //_videoPreviewLayer = nil;
}

#pragma mark --
- (void)captureStillImage {
    if (_captureSession) {
        [self captureNow:[self settingCaptureStillImageOutputToSession:_captureSession]];
    }
}

- (AVCaptureStillImageOutput *)settingCaptureStillImageOutputToSession:(AVCaptureSession *)captureSession {
    AVCaptureStillImageOutput *stillImageOutput = [AVCaptureStillImageOutput new];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [stillImageOutput setOutputSettings:outputSettings];
    if ([captureSession canAddOutput:stillImageOutput]) {
        [captureSession addOutput:stillImageOutput];
    }
    return stillImageOutput;
}

-(void)captureNow:(AVCaptureStillImageOutput *)stillImageOutput {
    
    // Start the session running to start the flow of data
    if (!_captureSession.isRunning) {
        [_captureSession startRunning];
    }
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in stillImageOutput.connections)
    {
        for (AVCaptureInputPort *port in [connection inputPorts])
        {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    
    [stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *__strong error) {
        CFDictionaryRef exifAttachments = CMGetAttachment( imageDataSampleBuffer, kCGImagePropertyExifDictionary, NULL);
        if (exifAttachments) { // Do something with the attachments.
            NSLog(@"attachements: %@", exifAttachments);
        } else {
            NSLog(@"no attachments");
        }
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *image = [[UIImage alloc] initWithData:imageData];
    }];
    
}

#pragma mark --
- (void)captureVideoData {
    [self addCaptureVideoDataOutputToSession:_captureSession];
}

- (void)addCaptureVideoDataOutputToSession:(AVCaptureSession *)captureSession {
    // 创建一个VideoDataOutput对象，将其添加到session
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [captureSession addOutput:output];
    
    // 配置output对象
    dispatch_queue_t queue = dispatch_queue_create("myQueueVideoData", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    //dispatch_release(queue);
    
    // 指定像素格式
    output.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    
    // 如果你想将视频的帧数指定一个顶值, 例如15ps
    // 可以设置minFrameDuration（该属性在iOS 5.0中弃用）
    //output.minFrameDuration = CMTimeMake(1, 15);
    
    //将output附给实例变量
    [self setVideoDataOutput:output];
}

#pragma mark --
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects
      fromConnection:(AVCaptureConnection *)connection
{
    if (!_isReading) return;
    
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        NSString *stringValue = metadataObj.stringValue;
        NSLog(@"stringValue:%@",stringValue);
        
        //Do Something....
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self invalidateTimer];
            [self stopReading];
            
            _textViewResult.text = stringValue;
            if (self.qrcodeResultBlock) {
                self.qrcodeResultBlock(metadataObj, stringValue);
            }
        });
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSDictionary* dict = (NSDictionary*)CMGetAttachment(sampleBuffer, kCGImagePropertyExifDictionary, NULL);
    NSLog(@"ExifDictionary:%@",dict);
    if (dict && dict[@"BrightnessValue"]) {
        if (!_mArrayBrightnessValues) {
            _mArrayBrightnessValues = [NSMutableArray array];
        }
        [_mArrayBrightnessValues addObject:dict[@"BrightnessValue"]];
    }
    if (_captureVideoDataOutput) {
        if (_mArrayBrightnessValues.count >= 10) {
            [_captureVideoDataOutput setSampleBufferDelegate:nil queue:nil];
            CGFloat average = 0.f;
            for (NSString *strBrightnessValue in _mArrayBrightnessValues) {
                average += [strBrightnessValue floatValue];
            }
            average = average / _mArrayBrightnessValues.count;
            NSLog(@"brightness values average:%f",average);
            if (average < 1) {//这个值不知道怎么定，先给个1吧。。
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self turnOnLed:YES];
                });
            }
        }
    }
}

#pragma mark -- button action
- (IBAction)buttonAlbumAction:(UIButton *)sender {
    sender.selected = !sender.selected;
    //[sender setImage:sender.selected?[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_btn_photo_down"]:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_btn_photo_nor"] forState:UIControlStateNormal];
    
    _textViewResult.text = @"";
    [self detectQRCodeFromAlbum];
}

- (IBAction)buttonLightAction:(UIButton *)sender {
    sender.selected = !sender.selected;
    [sender setImage:sender.selected?[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_btn_flash_down"]:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_btn_flash_nor"] forState:UIControlStateNormal];
    if (isLightOn)
    {
        [self turnOffLed:YES];
    }
    else
    {
        [self turnOnLed:YES];
    }
}

- (IBAction)buttonMyQRCodeAction:(UIButton *)sender {
    sender.selected = !sender.selected;
    //[sender setImage:sender.selected?[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_btn_myqrcode_down"]:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_btn_myqrcode_nor"] forState:UIControlStateNormal];
    MyQRCodeViewController *myQRCodeVC = [[MyQRCodeViewController alloc] initWithNibName:@"MyQRCodeViewController" bundle:nil];
    //myQRCodeVC.customColor = [UIColor redColor];
    if (self.strMyQRCode) {
        myQRCodeVC.strForQRCode = self.strMyQRCode;//strForQRCode和strForBarCode二选一，优先判断二维码
    } else {
        myQRCodeVC.strForQRCode = @"http://www.baidu.com";//strForQRCode和strForBarCode二选一，优先判断二维码
    }
    /*
    if (self.strMyBarCode) {
        myQRCodeVC.strForBarCode = self.strMyBarCode;//strForQRCode和strForBarCode二选一，优先判断二维码
    } else {
        myQRCodeVC.strForBarCode = @"6922233623211";//strForQRCode和strForBarCode二选一，优先判断二维码
    }
    */
    myQRCodeVC.iconImage = self.iconImage;
    myQRCodeVC.iconSize = CGSizeMake(40.0, 50.0);
    [self.navigationController pushViewController:myQRCodeVC animated:YES];
}

- (IBAction)buttonScanAction:(UIButton *)sender {
    [self startReading];
    if (self.scanLineFlag) {
        [self initTimer];
    }
    _textViewResult.text = @"";
}

- (IBAction)buttonStopScanAction:(UIButton *)sender {
    [self stopReading];
}

#pragma mark --
//从相册选择图片
- (void)detectQRCodeFromAlbum {
    UIImagePickerController *pickerImage = [[UIImagePickerController alloc] init];
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        pickerImage.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        //pickerImage.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        pickerImage.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:pickerImage.sourceType];
        
    }
    pickerImage.delegate = self;
    pickerImage.allowsEditing = NO;
    [self presentViewController:pickerImage animated:YES completion:nil];
}

#pragma mark --
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{}];
    
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    /* 此处info 有六个值
     * UIImagePickerControllerMediaType; // an NSString UTTypeImage)
     * UIImagePickerControllerOriginalImage;  // a UIImage 原始图片
     * UIImagePickerControllerEditedImage;    // a UIImage 裁剪后图片
     * UIImagePickerControllerCropRect;       // an NSValue (CGRect)
     * UIImagePickerControllerMediaURL;       // an NSURL
     * UIImagePickerControllerReferenceURL    // an NSURL that references an asset in the AssetsLibrary framework
     * UIImagePickerControllerMediaMetadata    // an NSDictionary containing metadata from a captured photo
     */
    /*
     // 保存图片至本地，方法见下文
     [self saveImage:image withName:@"currentImage.png"];
     
     NSString *fullPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"currentImage.png"];
     
     UIImage *savedImage = [[UIImage alloc] initWithContentsOfFile:fullPath];
     */
    
    /*
     NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
     
     NSData *data;
     
     if ([mediaType isEqualToString:@"public.image"]){
     
     //切忌不可直接使用originImage，因为这是没有经过格式化的图片数据，可能会导致选择的图片颠倒或是失真等现象的发生，从UIImagePickerControllerOriginalImage中的Origin可以看出，很原始，哈哈
     UIImage *originImage = [info objectForKey:UIImagePickerControllerOriginalImage];
     
     //图片压缩，因为原图都是很大的，不必要传原图
     UIImage *scaleImage = [self scaleImage:originImage toScale:0.3];
     
     //以下这两步都是比较耗时的操作，最好开一个HUD提示用户，这样体验会好些，不至于阻塞界面
     if (UIImagePNGRepresentation(scaleImage) == nil) {
     //将图片转换为JPG格式的二进制数据
     data = UIImageJPEGRepresentation(scaleImage, 1);
     } else {
     //将图片转换为PNG格式的二进制数据
     data = UIImagePNGRepresentation(scaleImage);
     }
     
     //将二进制数据生成UIImage
     UIImage *image = [UIImage imageWithData:data];
     }
     */
    
    NSLog(@"info : %@",info);
    // 照片
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    
    //NSData *data;
    
    if ([mediaType isEqualToString:@"public.image"]){
        NSURL *url = [info objectForKey:@"UIImagePickerControllerReferenceURL"];
        NSLog(@"url : %@",url);
        //[self readQRCodeFromImageWithFileUrL:url];
        NSString *filePath = [self saveImage:image withName:@"detectQRCodeImage.png"];
        if (filePath) {
            [self readQRCodeFromImageWithFileUrL:[NSURL fileURLWithPath:filePath]];
        }
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:^{}];
}

#pragma mark- 缩放图片
-(UIImage *)scaleImage:(UIImage *)image toScale:(float)scaleSize
{
    UIGraphicsBeginImageContext(CGSizeMake(image.size.width*scaleSize,image.size.height*scaleSize));
    [image drawInRect:CGRectMake(0, 0, image.size.width * scaleSize, image.size.height *scaleSize)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}

#pragma mark - 保存图片至沙盒
- (NSString *) saveImage:(UIImage *)currentImage withName:(NSString *)imageName
{
    //此方法可将图片压缩，但是图片质量基本不变，第二个参数即图片质量参数
    NSData *imageData = UIImageJPEGRepresentation(currentImage, 0.5);
    // 获取沙盒目录
    
    NSString *fullPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:imageName];
    // 将图片写入文件
    
    BOOL success = [imageData writeToFile:fullPath atomically:NO];
    if (success) {
        return fullPath;
    }
    return nil;
}

#pragma mark --
//打开LED闪光灯
-(void)turnOnLed:(bool)update
{
    dispatch_async(dispatch_get_main_queue(), ^(){
        if ([device hasTorch])
        {
            [device lockForConfiguration:nil];
            [device setTorchMode:AVCaptureTorchModeOn];
            [device unlockForConfiguration];
        }
        if (update)
        {
            isLightOn=YES;
            _buttonLight.selected = isLightOn;
            [_buttonLight setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_btn_flash_down"] forState:UIControlStateNormal];
        }
    });
}

//关闭LED闪光灯
-(void)turnOffLed:(bool)update
{
    dispatch_async(dispatch_get_main_queue(), ^(){
        if ([device hasTorch])
        {
            [device lockForConfiguration:nil];
            [device setTorchMode:AVCaptureTorchModeOff];
            [device unlockForConfiguration];
        }
        if (update)
        {
            isLightOn=NO;
            _buttonLight.selected = isLightOn;
            [_buttonLight setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_btn_flash_nor"] forState:UIControlStateNormal];
        }
    });
}

#pragma mark -- 解码二维码图片
//iOS8可以直接使用CIQRCodeFeature解码二维码图片//引入<CoreImage/CoreImage.h>
- (void)readQRCodeFromImageWithFileUrL:(NSURL *)url {
    // 根据URL找到CIImage
    CIImage *image = [CIImage imageWithContentsOfURL:url];
    if (image) {
        // 创建CIDetector
        CIDetector *qrDetector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:[CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer : @(YES)}] options:@{CIDetectorAccuracy : CIDetectorAccuracyHigh}];
        NSArray *features = [qrDetector featuresInImage:image];
        if ([features count] > 0) {
            for (CIFeature *feature in features) {
                if (![feature isKindOfClass:[CIQRCodeFeature class]]) {
                    continue;
                }
                
                CIQRCodeFeature *qrFeature = (CIQRCodeFeature *)feature;
                NSString *code = qrFeature.messageString;
                NSLog(@"content is : %@",code);
                dispatch_async(dispatch_get_main_queue(), ^{
                    _textViewResult.text = code;
                    if (self.qrcodeResultBlock) {
                        self.qrcodeResultBlock(qrFeature, code);
                    }
                });
            }
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -- utils
- (void)alertInViewController:(UIViewController *)viewController alertTitle:(NSString *)title message:(NSString *)msg actionTitle:(NSString *)actionTitle actionHandler:(void (^ __nullable)(UIAlertAction *action))actionHandler otherActionTitle:(NSString *)cancelTitle otherActionHandler:(void (^ __nullable)(UIAlertAction *action))otherActionHandler {
    //iOS8下使用UIAlertController
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if([[UIDevice currentDevice].systemVersion floatValue] >= 8.0){
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        if (actionTitle) {
            UIAlertAction *alertAction = [UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:actionHandler];
            [alertController addAction:alertAction];
        }
        if (cancelTitle) {
            UIAlertAction *otherAlertAction = [UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleDefault handler:otherActionHandler];
            [alertController addAction:otherAlertAction];
        }
        [viewController presentViewController:alertController animated:YES completion:nil];
    } else {
#endif
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:msg delegate:viewController cancelButtonTitle:nil otherButtonTitles:actionTitle, cancelTitle,  nil];
        [alertView show];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    }
#endif
}

@end
