//
//  ScanQRCodeViewController.h
//  Test_QRCode
//
//  Created by forp on 15/12/31.
//  Copyright © 2015年 forp. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef void (^QRCodeBlock)(id object, NSString *result);

@interface ScanQRCodeViewController : UIViewController

@property (nonatomic, assign) BOOL qrcodeFlag;//是否仅支持二维码
@property (nonatomic, assign) BOOL fullScreenFlag;//是否全屏(样式)
@property (nonatomic, assign) BOOL scanLineFlag;//是否加扫描线
@property (nonatomic, strong) UIImage *iconImage;//是否加logo
@property (nonatomic, strong) NSString *strMyQRCode;//自定义二维码字符串
@property (nonatomic, strong) NSString *strMyBarCode;//自定义条形码字符串

@property(nonatomic,copy)QRCodeBlock qrcodeResultBlock;

@end
