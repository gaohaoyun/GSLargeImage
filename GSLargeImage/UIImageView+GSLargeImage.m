//
//  UIImageView+GSLargeImage.m
//  GSLargeImageDemo
//
//  Created by MarsGao on 16/8/25.
//  Copyright © 2016年 MarsGao. All rights reserved.
//

#import "UIImageView+GSLargeImage.h"
//1M = 1048576.0f byte
#define bytesPerMB 1048576.0f

//每个像素点所占byte大小
#define bytesPerPixel 4.0f //还是4.0f？
#define pixelsPerMB ( bytesPerMB / bytesPerPixel ) //1M 可以包含 262144pixel  ； 2642144pixel / M
//图片在内从中最终的大小
#define destTotalPixels 80 * pixelsPerMB
#define tileTotalPixels 10 * pixelsPerMB
#define destSeemOverlap 1.0f

@implementation UIImageView (GSLargeImage)

- (void)gs_setLargeImage:(UIImage *)largeImage{

    UIImage *originalImage = largeImage;
    if (!originalImage) {
        return;
    }
    
    UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    [activity setCenter:CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2)];
    [self addSubview:activity];
    [activity startAnimating];
    __block CGContextRef destContext;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //原图的分辨率
        CGSize originalResolution;
        originalResolution.width = CGImageGetWidth(originalImage.CGImage);
        originalResolution.height = CGImageGetHeight(originalImage.CGImage);
        float originalTotalPixels = originalResolution.width * originalResolution.height;
        
        float imageScale = destTotalPixels / originalTotalPixels; //最终的大小与原图的比例
        
        CGSize destResolution;//最终的分辨率
        destResolution.width = (int)(originalResolution.width * imageScale);
        destResolution.height = (int)(originalResolution.height * imageScale);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();//颜色通道
        int bytesPreRow = bytesPerPixel * destResolution.width;
        void* destBitmapData = malloc(bytesPreRow * destResolution.height);
        destContext = CGBitmapContextCreate(destBitmapData, destResolution.width, destResolution.height, 8, bytesPreRow, colorSpace, kCGImageAlphaPremultipliedLast);
        if (destContext == NULL) {
            free(destBitmapData);
            NSLog(@"error");
        }
        
        CGColorSpaceRelease(colorSpace);
        CGContextTranslateCTM(destContext, 0.0f, destResolution.height);
        CGContextScaleCTM(destContext, 1.0f, -1.0f);
        
        CGRect originalTile;
        originalTile.size.width = originalResolution.width;
        originalTile.size.height = (int)(tileTotalPixels / originalTile.size.width);
        originalTile.origin.x = 0.f;
        originalTile.origin.y = 0.f;
        
        CGRect destTile;
        destTile.size.width = destResolution.width;
        destTile.size.height = originalTile.size.height * imageScale;
        destTile.origin.x = 0.0f;
        destTile.origin.y = 0;
        
        CGImageRef sourceTileImageRef = NULL;//每一行绘制
        int numberOfTile = (int)originalResolution.height / (int)originalTile.size.height;//需要渲染行数
        int remainder = (int)originalResolution.height % (int)originalTile.size.height;
        if (remainder) {
            numberOfTile ++ ;
        }
        float originalHeightPreTile = originalTile.size.height;
        
        float originalSeemOverlap = (destSeemOverlap/destResolution.height)*originalResolution.height;
        
        originalTile.size.height += originalSeemOverlap;
        
        destTile.size.height += destSeemOverlap;
        
        for (int idx = 0; idx < numberOfTile; idx++) {
            
            originalTile.origin.y = idx * originalHeightPreTile +originalSeemOverlap;
            destTile.origin.y = (destResolution.height) - ((idx + 1) * originalHeightPreTile * imageScale + destSeemOverlap);
            sourceTileImageRef = CGImageCreateWithImageInRect(originalImage.CGImage, originalTile);
            if (idx == numberOfTile - 1 && remainder) {//如果是最后一行
                float dify = destTile.size.height;
                destTile.size.height = CGImageGetHeight(sourceTileImageRef)*imageScale;
                dify -= destTile.size.height;
                destTile.origin.y += dify;
            }
            CGContextDrawImage(destContext, destTile, sourceTileImageRef);
            CGImageRelease(sourceTileImageRef);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            CGImageRef destImageRef = CGBitmapContextCreateImage(destContext);
            if (destImageRef) {
                self.image = [UIImage imageWithCGImage:destImageRef scale:1.0f orientation:UIImageOrientationDownMirrored];
                CGImageRelease(destImageRef);
            }
            [activity stopAnimating];
            [activity removeFromSuperview];
        });
    });
}

@end
