//
//  MyQRCodeViewController.m
//  Test_QRCode
//
//  Created by forp on 16/1/5.
//  Copyright © 2016年 forp. All rights reserved.
//

#import "MyQRCodeViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>  //
#import <CoreMotion/CoreMotion.h>
#import <AudioToolbox/AudioToolbox.h>

#import "KMQRCode.h"
#import "UIImage+RoundedRectImage.h"

// 照片原图路径
#define KOriginalPhotoImagePath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"OriginalPhotoImages"]

// 视频URL路径
#define KVideoUrlPath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"VideoURL"]

// caches路径
#define KCachesPath [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]

@interface MyQRCodeViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIAlertViewDelegate> {
    CMMotionManager *_motionManager;
    NSOperationQueue *_operationQueue;
    BOOL _isShake;
    BOOL _isOver;
    NSInteger _beginTimestamp;
    NSInteger _second;
    NSInteger _shakesCount;
}
@property (strong, nonatomic) IBOutlet UIImageView *qrcodeView;

@end

@implementation MyQRCodeViewController

#pragma mark --
/*
 // ios本身就支持摇一摇
 // 在 UIResponder 中存在这么一套方法
 
 - (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
 
 - (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
 
 - (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
 
 //这就是执行摇一摇的方法。那么怎么用这些方法呢？
 
 //很简单，你只需要让这个Controller本身支持摇动
 
 //同时让他成为第一相应者：
 */
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

- (void) viewWillAppear:(BOOL)animated
{
    [self resignFirstResponder];
    [super viewWillAppear:animated];
}

- (void)viewDidLoad {
    // 设置允许摇一摇功能
    [UIApplication sharedApplication].applicationSupportsShakeToEdit = YES;//在ios6.0后，这里其实都可以不写了
    // 并让自己成为第一响应者
    [self becomeFirstResponder];
    
    //设置摇一摇
    [self setupShake];
    
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    if (self.strForQRCode) {
        [self showQRCode];
    } else if (self.strForBarCode) {
        [self showBarCode];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showBarCode {
    if (self.strForBarCode) {
        self.qrcodeView.image = [self generateBarCode:self.strForBarCode width:self.qrcodeView.frame.size.width height:self.qrcodeView.frame.size.height];
    }
}

- (void)showQRCode {
    UIImage *qrcode = [self createNonInterpolatedUIImageFormCIImage:[self createQRForString:(self.strForQRCode?self.strForQRCode:@"www.baidu.com")] withSize:250.0f];
    UIImage *customQrcode = nil;
    if (self.customColor) {
        NSArray *arrColorRGB = [self changeUIColorToRGB:self.customColor];
        if (3 == arrColorRGB.count) {
            customQrcode = [self imageBlackToTransparent:qrcode withRed:[arrColorRGB[0] floatValue] andGreen:[arrColorRGB[1] floatValue] andBlue:[arrColorRGB[2] floatValue]];
        }
    } else {
        customQrcode = [self imageBlackToTransparent:qrcode withRed:60.0f andGreen:74.0f andBlue:89.0f];
    }
    if (self.iconImage) {
        //使用核心绘图框架CG（Core Graphics）对象操作，创建带圆角效果的图片
        UIImage *imgIcon = nil;
        if ((0 != self.iconSize.width) && (0 != self.iconSize.height)) {
            imgIcon = [UIImage createRoundedRectImage:self.iconImage
                                                      withSize:self.iconSize
                                                    withRadius:10];
        } else {
            imgIcon = [UIImage createRoundedRectImage:self.iconImage
                                                      withSize:CGSizeMake(70.0, 93.0)
                                                    withRadius:10];
        }
        //使用核心绘图框架CG（Core Graphics）对象操作，合并二维码图片和用于中间显示的图标图片
        customQrcode = [KMQRCode addIconToQRCodeImage:customQrcode
                                                  withIcon:imgIcon
                                              withIconSize:imgIcon.size];
    }
    self.qrcodeView.image = customQrcode;
    // set shadow
    self.qrcodeView.layer.shadowOffset = CGSizeMake(0, 2);
    self.qrcodeView.layer.shadowRadius = 2;
    self.qrcodeView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.qrcodeView.layer.shadowOpacity = 0.5;
}

#pragma mark - InterpolatedUIImage
- (UIImage *)createNonInterpolatedUIImageFormCIImage:(CIImage *)image withSize:(CGFloat) size {
    CGRect extent = CGRectIntegral(image.extent);
    CGFloat scale = MIN(size/CGRectGetWidth(extent), size/CGRectGetHeight(extent));
    // create a bitmap image that we'll draw into a bitmap context at the desired size;
    size_t width = CGRectGetWidth(extent) * scale;
    size_t height = CGRectGetHeight(extent) * scale;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:image fromRect:extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    // Create an image with the contents of our bitmap
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);
    // Cleanup
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    return [UIImage imageWithCGImage:scaledImage];
}

#pragma mark - QRCodeGenerator
- (CIImage *)createQRForString:(NSString *)qrString {
    // Need to convert the string to a UTF-8 encoded NSData object
    NSData *stringData = [qrString dataUsingEncoding:NSUTF8StringEncoding];
    // Create the filter
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    // Set the message content and error-correction level
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"M" forKey:@"inputCorrectionLevel"];
    // Send the image back
    return qrFilter.outputImage;
}

/*KMQRCode.m里面定义过了
#pragma mark - imageToTransparent
void ProviderReleaseData (void *info, const void *data, size_t size){
    free((void*)data);
}
*/
#pragma mark - imageToTransparent
void MyQRCodeProviderReleaseData (void *info, const void *data, size_t size){
    free((void*)data);
}

- (UIImage*)imageBlackToTransparent:(UIImage*)image withRed:(CGFloat)red andGreen:(CGFloat)green andBlue:(CGFloat)blue{
    const int imageWidth = image.size.width;
    const int imageHeight = image.size.height;
    size_t      bytesPerRow = imageWidth * 4;
    uint32_t* rgbImageBuf = (uint32_t*)malloc(bytesPerRow * imageHeight);
    // create context
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rgbImageBuf, imageWidth, imageHeight, 8, bytesPerRow, colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
    CGContextDrawImage(context, CGRectMake(0, 0, imageWidth, imageHeight), image.CGImage);
    // traverse pixe
    int pixelNum = imageWidth * imageHeight;
    uint32_t* pCurPtr = rgbImageBuf;
    for (int i = 0; i < pixelNum; i++, pCurPtr++){
        if ((*pCurPtr & 0xFFFFFF00) < 0x99999900){
            // change color
            uint8_t* ptr = (uint8_t*)pCurPtr;
            ptr[3] = red; //0~255
            ptr[2] = green;
            ptr[1] = blue;
        }else{
            uint8_t* ptr = (uint8_t*)pCurPtr;
            ptr[0] = 0;
        }
    }
    // context to image
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, rgbImageBuf, bytesPerRow * imageHeight, MyQRCodeProviderReleaseData);
    CGImageRef imageRef = CGImageCreate(imageWidth, imageHeight, 8, 32, bytesPerRow, colorSpace,
                                        kCGImageAlphaLast | kCGBitmapByteOrder32Little, dataProvider,
                                        NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    UIImage* resultUIImage = [UIImage imageWithCGImage:imageRef];
    // release
    CGImageRelease(imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    return resultUIImage;
}

/*
//将UIColor转换为RGB值//这种方法。。
- (NSMutableArray *) changeUIColorToRGB:(UIColor *)color
{
    NSMutableArray *RGBStrValueArr = [[NSMutableArray alloc] init];
    NSString *RGBStr = nil;
    //获得RGB值描述
    NSString *RGBValue = [NSString stringWithFormat:@"%@",color];
    //将RGB值描述分隔成字符串
    NSArray *RGBArr = [RGBValue componentsSeparatedByString:@" "];
    //获取红色值
    int r = [[RGBArr objectAtIndex:1] intValue] * 255;
    RGBStr = [NSString stringWithFormat:@"%d",r];
    [RGBStrValueArr addObject:RGBStr];
    //获取绿色值
    int g = [[RGBArr objectAtIndex:2] intValue] * 255;
    RGBStr = [NSString stringWithFormat:@"%d",g];
    [RGBStrValueArr addObject:RGBStr];
    //获取蓝色值
    int b = [[RGBArr objectAtIndex:3] intValue] * 255;
    RGBStr = [NSString stringWithFormat:@"%d",b];
    [RGBStrValueArr addObject:RGBStr];
    //返回保存RGB值的数组
    return RGBStrValueArr;
}
*/

//将UIColor转换为RGB值//这种方法更靠谱些。。
- (NSMutableArray *) changeUIColorToRGB:(UIColor *)customColor
{
    CGFloat R, G, B;
    
    CGColorRef color = [customColor CGColor];
    NSInteger numComponents = CGColorGetNumberOfComponents(color);
    
    if (numComponents == 4)
    {
        const CGFloat *components = CGColorGetComponents(color);
        R = components[0];
        G = components[1];
        B = components[2];
        
        NSMutableArray *mArrRGB = [NSMutableArray array];
        [mArrRGB addObject:[NSNumber numberWithFloat:R * 255]];
        [mArrRGB addObject:[NSNumber numberWithFloat:G * 255]];
        [mArrRGB addObject:[NSNumber numberWithFloat:B * 255]];
        return mArrRGB;
    }
    //返回保存RGB值的数组
    return nil;
}

#pragma mark - 生成条形码以及二维码

// 参考文档
// https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html

- (UIImage *)generateQRCode:(NSString *)code width:(CGFloat)width height:(CGFloat)height {
    
    // 生成二维码图片
    CIImage *qrcodeImage;
    NSData *data = [code dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:false];
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    
    [filter setValue:data forKey:@"inputMessage"];
    [filter setValue:@"H" forKey:@"inputCorrectionLevel"];
    qrcodeImage = [filter outputImage];
    
    // 消除模糊
    CGFloat scaleX = width / qrcodeImage.extent.size.width; // extent 返回图片的frame
    CGFloat scaleY = height / qrcodeImage.extent.size.height;
    CIImage *transformedImage = [qrcodeImage imageByApplyingTransform:CGAffineTransformScale(CGAffineTransformIdentity, scaleX, scaleY)];
    
    return [UIImage imageWithCIImage:transformedImage];
}

- (UIImage *)generateBarCode:(NSString *)code width:(CGFloat)width height:(CGFloat)height {
    // 生成二维码图片
    CIImage *barcodeImage;
    NSData *data = [code dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:false];
    CIFilter *filter = [CIFilter filterWithName:@"CICode128BarcodeGenerator"];
    
    [filter setValue:data forKey:@"inputMessage"];
    barcodeImage = [filter outputImage];
    
    // 消除模糊
    CGFloat scaleX = width / barcodeImage.extent.size.width; // extent 返回图片的frame
    CGFloat scaleY = height / barcodeImage.extent.size.height;
    CIImage *transformedImage = [barcodeImage imageByApplyingTransform:CGAffineTransformScale(CGAffineTransformIdentity, scaleX, scaleY)];
    
    return [UIImage imageWithCIImage:transformedImage];
}

#pragma mark --
- (void)layoutUI {
    //用于生成二维码的字符串source
    NSString *source = @"https://github.com/KenmuHuang";
    
    //使用iOS 7后的CIFilter对象操作，生成二维码图片imgQRCode（会拉伸图片，比较模糊，效果不佳）
    CIImage *imgQRCode = [KMQRCode createQRCodeImage:source];
    
    //使用核心绘图框架CG（Core Graphics）对象操作，进一步针对大小生成二维码图片imgAdaptiveQRCode（图片大小适合，清晰，效果好）
    UIImage *imgAdaptiveQRCode = [KMQRCode resizeQRCodeImage:imgQRCode
                                                    withSize:_qrcodeView.frame.size.width];
    
    //默认产生的黑白色的二维码图片；我们可以让它产生其它颜色的二维码图片，例如：蓝白色的二维码图片
    imgAdaptiveQRCode = [KMQRCode specialColorImage:imgAdaptiveQRCode
                                            withRed:33.0
                                              green:114.0
                                               blue:237.0]; //0~255
    if (self.iconImage) {
        //使用核心绘图框架CG（Core Graphics）对象操作，创建带圆角效果的图片
        UIImage *imgIcon = [UIImage createRoundedRectImage:self.iconImage
                                                  withSize:CGSizeMake(70.0, 93.0)
                                                withRadius:10];
        //使用核心绘图框架CG（Core Graphics）对象操作，合并二维码图片和用于中间显示的图标图片
        imgAdaptiveQRCode = [KMQRCode addIconToQRCodeImage:imgAdaptiveQRCode
                                                  withIcon:imgIcon
                                              withIconSize:imgIcon.size];
    }
    
    //    imgAdaptiveQRCode = [KMQRCode addIconToQRCodeImage:imgAdaptiveQRCode
    //                                              withIcon:imgIcon
    //                                             withScale:3];
    
    _qrcodeView.image = imgAdaptiveQRCode;
    //设置图片视图的圆角边框效果
    _qrcodeView.layer.masksToBounds = YES;
    _qrcodeView.layer.cornerRadius = 10.0;
    _qrcodeView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    _qrcodeView.layer.borderWidth = 4.0;
}

#pragma mark -
#pragma mark 摇一摇
- (BOOL)canBecomeFirstResponder
{
    return YES;// default is NO
}

- (void)setupShake {
    _motionManager = [[CMMotionManager alloc] init];
    
    _operationQueue = [[NSOperationQueue alloc] init];
    
    _isShake = NO;                  // 是否在摇动
    
    _isOver = NO;              // 是否摇动已经结束
    
    _beginTimestamp = 0;  // 开始摇奖的时间戳
    
    _motionManager.accelerometerUpdateInterval = 1;
}

- (void)initShake {
    
    _isShake = YES;                  // 是否在摇动
    
    _isOver = NO;              // 是否摇动已经结束
    
    _beginTimestamp = 0;  // 开始摇奖的时间戳
    
    [_motionManager startAccelerometerUpdatesToQueue:_operationQueue withHandler:^(CMAccelerometerData *latestAcc, NSError *error) {
        
        dispatch_sync(dispatch_get_main_queue(), ^(void) {
            
            // 所有操作进行同步
            
            @synchronized(_motionManager) {
                
                _isShake = [self isShake:_motionManager.accelerometerData];
                
                if (_beginTimestamp == 0 && _isShake == YES) {
                    
                    _second = 0;
                    
                    NSLog(@"摇奖开始了");
                    
                    _beginTimestamp = [[NSDate date] timeIntervalSince1970];
                    
                }
                
                if (_beginTimestamp != 0 && _isShake == NO) {
                    
                    _isOver = YES;
                    
                }
                
                // 此时为摇奖结束
                
                if (_isOver) {
                    
                    // 停止检测摇动事件
                    
                    [_motionManager stopAccelerometerUpdates];
                    
                    // 取消队列中排队的其它请求
                    
                    [_operationQueue cancelAllOperations];
                    
                    NSInteger currentTimestamp = [[NSDate date] timeIntervalSince1970];
                    
                    // 摇动的持续时间
                    
                    NSInteger second = currentTimestamp - _beginTimestamp;
                    
                    _second = second;
                    
                    NSLog(@"摇一摇结束， 持续时间为:%zd", second);
                    
                    [self justForFun];
                    
                    _isShake = NO;
                }
                
            }
            
        });
        
    }];
    
}

- (void)justForFun {
    if (_shakesCount <= 0) {
        [self alertInViewController:self alertTitle:@"温馨提示：" message:[NSString stringWithFormat:@"您摇动了手机%zd秒，想干嘛？",_second] actionTitle:@"CANCEL" actionHandler:^(UIAlertAction *action) {
            if (_shakesCount > 0) {
                //_shakesCount --;//不起作用因为alertview出现之后就得先处理弹出框。。
            }
        } otherActionTitle:nil otherActionHandler:nil];
    } else if (_shakesCount <= 2) {
        [self alertInViewController:self alertTitle:@"温馨提示：" message:[NSString stringWithFormat:@"您又摇动了手机%zd秒，又想干嘛？",_second] actionTitle:@"CANCEL" actionHandler:^(UIAlertAction *action) {
            if (_shakesCount > 0) {
                //_shakesCount --;//不起作用因为alertview出现之后就得先处理弹出框。。
            }
        } otherActionTitle:nil otherActionHandler:nil];
    } else if (_shakesCount == 3) {
        [self alertInViewController:self alertTitle:@"温馨提示：" message:[NSString stringWithFormat:@"您又摇动了手机%zd秒，再摇我生气了！",_second] actionTitle:@"CANCEL" actionHandler:^(UIAlertAction *action) {
            if (_shakesCount > 0) {
                //_shakesCount --;//不起作用因为alertview出现之后就得先处理弹出框。。
            }
        } otherActionTitle:nil otherActionHandler:nil];
    } else {
        [self alertInViewController:self alertTitle:@"温馨提示：" message:[NSString stringWithFormat:@"您又摇动了手机%zd秒，摇吧反正我已经生气了！",_second] actionTitle:@"CANCEL" actionHandler:^(UIAlertAction *action) {
            if (_shakesCount > 0) {
                //_shakesCount --;//不起作用因为alertview出现之后就得先处理弹出框。。
            }
        } otherActionTitle:nil otherActionHandler:nil];
    }
    
    _shakesCount ++;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([alertView.message containsString:@"摇动了手机"] && [alertView.message containsString:@"秒"]) {
        if (_shakesCount > 0) {
            //_shakesCount --;//不起作用因为alertview出现之后就得先处理弹出框。。
        }
    }
}

- (BOOL)isShake:(CMAccelerometerData *)newestAccel {
    
    BOOL isShake = NO;
    
    // 三个方向任何一个方向的加速度大于1.5就认为是处于摇晃状态，当都小于1.5时认为摇奖结束。
    
    //if (ABS(newestAccel.acceleration.x) > 1.5 || ABS(newestAccel.acceleration.y) > 1.5 || ABS(newestAccel.acceleration.z) > 1.5) {
    if (ABS(newestAccel.acceleration.x) > 1. || ABS(newestAccel.acceleration.y) > 1. || ABS(newestAccel.acceleration.z) > 1.) {
    
        isShake = YES;
        
    }
    
    return isShake;
    
}

//然后去实现这几个方法就可以了

#pragma mark - 摇一摇相关方法
// 摇一摇开始摇动
- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    NSLog(@"开始摇动");
    // 如果你想播放点声音
    //--播放特定的声音
    static SystemSoundID soundIDTest = 0;
    NSString * path = [[NSBundle mainBundle] pathForResource:@"shake_match" ofType:@"mp3"];
    if (path) {
        AudioServicesCreateSystemSoundID( (__bridge CFURLRef)[NSURL fileURLWithPath:path], &soundIDTest );
    }
    AudioServicesPlaySystemSound( soundIDTest );
    
    // 如果你想检测摇了多少秒
    if (!_isShake) {
        [self initShake];
    }
    
    return;
}

// 摇一摇取消摇动
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    NSLog(@"取消摇动");
    return;
}

// 摇一摇摇动结束
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (event.subtype == UIEventSubtypeMotionShake) { // 判断是否是摇动结束
        NSLog(@"摇动结束");
        //UIAlertView *alertYaoYiYao = [[UIAlertView alloc]initWithTitle:@"温馨提示：" message:@"您摇动了手机，想干嘛？" delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles: nil, nil];
        //[alertYaoYiYao show];
        
        //[self alertInViewController:self alertTitle:@"温馨提示：" message:[NSString stringWithFormat:@"您摇动了手机，想干嘛？"] actionTitle:@"CANCEL" actionHandler:nil otherActionTitle:nil otherActionHandler:nil];
        
        // 如果你想震动一下
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);// 静音模式下会震动..也是一种声音
    }
    return;
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
