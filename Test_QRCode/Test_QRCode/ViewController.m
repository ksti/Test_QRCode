//
//  ViewController.m
//  Test_QRCode
//
//  Created by forp on 15/12/31.
//  Copyright © 2015年 forp. All rights reserved.
//

#import "ViewController.h"
#import "ScanQRCodeViewController.h"

@interface ViewController () {
    
    __weak IBOutlet UITextView *_textViewQRCodeResult;
}

@end

@implementation ViewController

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

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    [self showScanView:nil];
}

- (IBAction)showScanView:(id)sender {
    ScanQRCodeViewController *scanQRCodeVC = [[ScanQRCodeViewController alloc] initWithNibName:@"ScanQRCodeViewController" bundle:nil];
    //[self presentViewController:scanQRCodeVC animated:YES completion:nil];
    [scanQRCodeVC.view setFrame:self.view.bounds];
    scanQRCodeVC.fullScreenFlag = YES;
    scanQRCodeVC.scanLineFlag = YES;
    scanQRCodeVC.strMyQRCode = @"郭军帅❤️白珍.Happy wife,happay Life.I Love my Family!";
    scanQRCodeVC.strMyBarCode = @"6925517201877";
    scanQRCodeVC.iconImage = [UIImage imageNamed:@"icon2.jpg"];
    __weak __typeof(scanQRCodeVC)weakscanQRCodeVC = scanQRCodeVC;
    scanQRCodeVC.qrcodeResultBlock = ^(id object, NSString *result) {
        _textViewQRCodeResult.text = result;
        //[weakscanQRCodeVC.view removeFromSuperview];
    };
    //[self.view addSubview:scanQRCodeVC.view];
    [self addChildViewController:scanQRCodeVC];
    [self.view addSubview:scanQRCodeVC.view];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
