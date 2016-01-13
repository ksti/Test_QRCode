//
//  MyQRCodeViewController.h
//  Test_QRCode
//
//  Created by forp on 16/1/5.
//  Copyright © 2016年 forp. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MyQRCodeViewController : UIViewController

@property (nonatomic, strong) NSString *strForQRCode;//生成二维码
@property (nonatomic, strong) NSString *strForBarCode;//生成条形码
@property (nonatomic, strong) UIColor *customColor;//生成的二维码颜色//二维码可用
@property (nonatomic, strong) UIImage *iconImage;//中间可以加logo
@property (nonatomic, assign) CGSize iconSize;//中间logo的(缩放)大小

@end
