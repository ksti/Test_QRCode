//
//  UIImage+RoundedRectImage.h
//  Test_QRCode
//
//  Created by forp on 16/1/6.
//  Copyright © 2016年 forp. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (RoundedRectImage)

 + (UIImage *)createRoundedRectImage:(UIImage *)image withSize:(CGSize)size withRadius:(NSInteger)radius;

@end
