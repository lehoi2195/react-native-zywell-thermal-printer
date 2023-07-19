//
//  ImageTranster.m
//  Printer
//
//  Created by LeeLee on 16/7/19.
//  Copyright © 2016年 Admin. All rights reserved.
//

#import "ImageTranster.h"

@implementation ImageTranster

#define Mask8(x) ((x)&0xFF)
#define A(x) (Mask8(x))
#define B(x) (Mask8(x>>8))
#define G(x) (Mask8(x>>16))
#define R(x)  (Mask8(x>>24))
#define RGBAMake(r,g,b,a)   (Mask8(a)|Mask8(b)<<8|Mask8(g)<<16|Mask8(r)<<24)

int p_0[] = { 0, 0x80 };
int p_1[] = { 0, 0x40 };
int p_2[] = { 0, 0x20 };
int p_3[] = { 0, 0x10 };
int p_4[] = { 0, 0x08 };
int p_5[] = { 0, 0x04 };
int p_6[] = { 0, 0x02 };

+(NSData *)Imagedata:(UIImage *) mIamge andType:(BmpType) bmptype{
    //NSMutableData *dataM=[[NSMutableData alloc] init];
    
    UInt32 aveGray;
    UInt32 sumGray=0;
    CGImageRef cgimage=[mIamge CGImage];
    size_t w=CGImageGetWidth(cgimage);
    size_t h=CGImageGetHeight(cgimage);
    UInt32 *pixels;
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
    
    NSInteger bpp=4;//每个像素的字节
    NSInteger bpc=8;//每个组成像素的位深
    NSInteger bpr=w*bpp;//每行字节数
    
    pixels=(UInt32 *)calloc(w*h,sizeof(UInt32));
    
    CGContextRef context=CGBitmapContextCreate(pixels, w, h, bpc, bpr, colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGContextDrawImage(context, CGRectMake(0, 0, w, h), cgimage);
    //操作像素
    UInt8 *gradPixels;
    gradPixels=(UInt8 *)calloc(w*h, sizeof(UInt8));
    //1.灰度处理
    for (NSInteger j=0; j<h; j++) {
        for (NSInteger i=0; i<w; i++) {
            UInt32 currentPixel=pixels[(w*j)+i];
            UInt32 color=currentPixel;
            //灰度化当前像素点
            UInt32 grayColor=//(R(color)+G(color)+B(color))/3;
            (R(color)*299+G(color)*587+B(color)*114)/1000;
            gradPixels[w*j+i]=grayColor;
            sumGray+=grayColor;
            // NSLog(@"%i",grayColor);
            pixels[w*j+i]=RGBAMake(grayColor, grayColor, grayColor, A(color));
            
        }
    }
    //2.黑白处理（二值法，抖动算法）
    //int e=0;
    //NSInteger g;
    //uint8_t *grayPixels;
    //int g;
    switch (bmptype) {
        case Dithering:
            
            //二值法处理
            aveGray=sumGray/(w*h);
            for (NSInteger j=0; j<h; j++) {
                for (NSInteger i=0; i<w; i++) {
                    UInt32 currentPixel=pixels[(w*j)+i];
                    UInt32 color=currentPixel;
                    if (R(color)<aveGray) {
                        pixels[w*j+i]=RGBAMake(0, 0, 0, A(color));
                    }else{
                        pixels[w*j+i]=RGBAMake(0xff, 0xff, 0xff, A(color));
                    }
                    
                }
            }
            
            break;
        case Threshold:
            //抖动算法
            for (NSInteger j=0; j<h; j++) {
                for (NSInteger i=0; i<w; i++) {
                    //UInt32 currentPixel=pixels[(w*j)+i];
                    //UInt32 color=*currentPixel;
                    NSInteger e=0;
                    NSInteger g=gradPixels[w*j+i];
                    if (g>=128) {
                        pixels[w*j+i]=RGBAMake(0xff, 0xff, 0xff, 0xff);
                        e=g-255;
                    }else{
                        pixels[w*j+i]=RGBAMake(0x00 , 0x00, 0x00, 0xff);
                        e=g-0;
                    }
                    
                    if (i<w-1&&j<h-1) {//不靠右边和下边的像素
                        //右边像素处理
                        //                        UInt8 leftPixel1=gradPixels[(w*j)+i+1];
                        //                        int lred1=Mask8(leftPixel1);
                        //                        lred1+=3*e/8;
                        //                       leftPixel1=lred1;
                        gradPixels[(w*j)+i+1]+=3*e/8;
                        
                        
                        //下边像素处理
                        //                        UInt8 lowPixel1=gradPixels[(w*j)+i+w];
                        //
                        //                        int lowred1=Mask8(lowPixel1);
                        //                        lowPixel1+=3*e/8;
                        //                        lowPixel1=lowred1;
                        gradPixels[(w*(j+1))+i]+=3*e/8;
                        //右下方像素处理
                        //                        UInt8 leftlowPixel1=gradPixels[(w*j)+i+w+1];
                        //                        int llred1=Mask8(leftlowPixel1);
                        //                       llred1+=e/4;
                        //                        leftlowPixel1=llred1;
                        gradPixels[w*(j+1)+i+1]+=e/4;
                        
                    }else if (i==w-1&&j<h-1){//靠右边界的像素
                        //下边像素处理
                        //                        UInt8 lowPixel1=gradPixels[(w*j)+i+w];
                        //
                        //                        int lowred1=Mask8(lowPixel1);
                        //                        lowred1+=3*e/8;
                        //                        lowPixel1=lowred1;
                        gradPixels[(w*(j+1))+i]+=3*e/8;
                        
                    }else if (i<w-1&&j==h-1){//靠底部的像素
                        
                        //右边像素处理
                        //                        UInt8 leftPixel1=gradPixels[(w*j)+i+1];
                        //                        int lred1=Mask8(leftPixel1);
                        //                        lred1+=3*e/8;
                        //                        leftPixel1=lred1;
                        gradPixels[(w*j)+i+1]+=e/4;
                    }
                }
            }
            
            break;
        default:
            break;
    }
    
    //将像素数据封装成打印机能识别的数据
    size_t n=(w+7)/8;
    uint8_t *newPixels;
    size_t m=0x01;
    newPixels=(uint8_t *)calloc(n*h, sizeof(uint8_t));
    for (NSInteger y=0; y<h; y++) {
        for (NSInteger x=0; x<n*8; x++) {
            if (x<w) {
                if (R(pixels[y*w+x])==0) {
                    newPixels[y*n+x/8]|=m<<(7-x%8);
                }
            }else if (x>=w){
                newPixels[y*n+x/8]|=0<<(7-x%8);
            }
        }
    }
    //3.通过处理后的像素来重新得到新的图片
    
    //直接返回像素数据会跟合适
    NSData *newdata=[NSData dataWithBytes:&newPixels length:sizeof(newPixels)];
    
    
    return newdata;
}
+(NSData *)rasterImagedata:(UIImage *) mIamge andType:(BmpType) bmptype andPrintRasterType:(PrintRasterType) type{
    //NSMutableData *dataM=[[NSMutableData alloc] init];
    
    //得到UIImage,获取图片像素，并转换为UInt32类型数据
    //int pixels[w*h];
    UInt32 aveGray;
    UInt32 sumGray=0;
    CGImageRef cgimage=[mIamge CGImage];
    size_t w=CGImageGetWidth(cgimage);
    size_t h=CGImageGetHeight(cgimage);
    UInt32 *pixels;
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
    
    NSInteger bpp=4;//每个像素的字节
    NSInteger bpc=8;//每个组成像素的位深
    NSInteger bpr=w*bpp;//每行字节数
    
    pixels=(UInt32 *)calloc(w*h,sizeof(UInt32));
    
    CGContextRef context=CGBitmapContextCreate(pixels, w, h, bpc, bpr, colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGContextDrawImage(context, CGRectMake(0, 0, w, h), cgimage);
    //操作像素
    UInt8 *gradPixels;
    gradPixels=(UInt8 *)calloc(w*h, sizeof(UInt8));
    //1.灰度处理
    for (NSInteger j=0; j<h; j++) {
        for (NSInteger i=0; i<w; i++) {
            UInt32 currentPixel=pixels[(w*j)+i];
            UInt32 color=currentPixel;
            //灰度化当前像素点
            UInt32 grayColor=//(R(color)+G(color)+B(color))/3;
            (R(color)*299+G(color)*587+B(color)*114+500)/1000;
            gradPixels[w*j+i]=grayColor;
            sumGray+=grayColor;
            // NSLog(@"%i",grayColor);
            pixels[w*j+i]=RGBAMake(grayColor, grayColor, grayColor, A(color));
            
        }
    }
    //2.黑白处理（二值法，抖动算法）
    //int e=0;
    //NSInteger g;
    //uint8_t *grayPixels;
    //int g;
    switch (bmptype) {
        case Dithering:
            
            //二值法处理
            aveGray=sumGray/(w*h);
            for (NSInteger j=0; j<h; j++) {
                for (NSInteger i=0; i<w; i++) {
                    UInt32 currentPixel=pixels[(w*j)+i];
                    UInt32 color=currentPixel;
                    if (R(color)<aveGray) {
                        pixels[w*j+i]=RGBAMake(0, 0, 0, A(color));
                    }else{
                        pixels[w*j+i]=RGBAMake(0xff, 0xff, 0xff, A(color));
                    }
                    
                }
            }
            
            break;
        case Threshold:
            //抖动算法
            for (NSInteger j=0; j<h; j++) {
                for (NSInteger i=0; i<w; i++) {
                    //UInt32 currentPixel=pixels[(w*j)+i];
                    //UInt32 color=*currentPixel;
                    NSInteger e=0;
                    NSInteger g=gradPixels[w*j+i];
                    if (g>=128) {
                        pixels[w*j+i]=RGBAMake(0xff, 0xff, 0xff, 0xff);
                        e=g-255;
                    }else{
                        pixels[w*j+i]=RGBAMake(0x00 , 0x00, 0x00, 0xff);
                        e=g-0;
                    }
                    
                    if (i<w-1&&j<h-1) {//不靠右边和下边的像素
                        //右边像素处理
                        //                        UInt8 leftPixel1=gradPixels[(w*j)+i+1];
                        //                        int lred1=Mask8(leftPixel1);
                        //                        lred1+=3*e/8;
                        //                       leftPixel1=lred1;
                        gradPixels[(w*j)+i+1]+=3*e/8;
                        
                        
                        //下边像素处理
                        //                        UInt8 lowPixel1=gradPixels[(w*j)+i+w];
                        //
                        //                        int lowred1=Mask8(lowPixel1);
                        //                        lowPixel1+=3*e/8;
                        //                        lowPixel1=lowred1;
                        gradPixels[(w*(j+1))+i]+=3*e/8;
                        //右下方像素处理
                        //                        UInt8 leftlowPixel1=gradPixels[(w*j)+i+w+1];
                        //                        int llred1=Mask8(leftlowPixel1);
                        //                       llred1+=e/4;
                        //                        leftlowPixel1=llred1;
                        gradPixels[w*(j+1)+i+1]+=e/4;
                        
                    }else if (i==w-1&&j<h-1){//靠右边界的像素
                        //下边像素处理
                        //                        UInt8 lowPixel1=gradPixels[(w*j)+i+w];
                        //
                        //                        int lowred1=Mask8(lowPixel1);
                        //                        lowred1+=3*e/8;
                        //                        lowPixel1=lowred1;
                        gradPixels[(w*(j+1))+i]+=3*e/8;
                        
                    }else if (i<w-1&&j==h-1){//靠底部的像素
                        
                        //右边像素处理
                        //                        UInt8 leftPixel1=gradPixels[(w*j)+i+1];
                        //                        int lred1=Mask8(leftPixel1);
                        //                        lred1+=3*e/8;
                        //                        leftPixel1=lred1;
                        gradPixels[(w*j)+i+1]+=e/4;
                    }
                }
            }
            
            break;
        default:
            break;
    }
    
    //将像素数据封装成打印机能识别的数据
    size_t n=(w+7)/8;
    uint8_t *newPixels;
    size_t m=0x01;
    Byte xL=n%256;
    Byte xH=n/256;
    size_t rep=(h+23)/24;
    newPixels=(uint8_t *)calloc(n*h, sizeof(uint8_t));
    for (NSInteger y=0; y<h; y++) {
        for (NSInteger x=0; x<n*8; x++) {
            if (x<w) {
                if (R(pixels[y*w+x])==0) {
                    newPixels[y*n+x/8]|=(m<<(7-x%8));
                }
            }else if (x>=w){
                newPixels[y*n+x/8]|=(0<<(7-x%8));
            }
        }
    }
    NSMutableData *dataM=[[NSMutableData alloc] init];
    //将像素数据封装成光栅位图格式
    Byte head[8]={0x1D,0x76,0x30,type,xL,xH,0x18,0x00};
    
    for (NSInteger i=0; i<rep; i++)
    {
        if (i==rep-1)
        {
            if (h%24==0)
            {
                head[6]=0x18;
                [dataM appendBytes:&head length:sizeof(head)];
                Byte cpyByte[24*n];
                memcpy(cpyByte, newPixels+(24*n*i), 24*n);
                
                [dataM appendBytes:&cpyByte length:sizeof(cpyByte)];
                
            }
            else
            {
                
                head[6]=h%24;
                [dataM appendBytes:&head length:sizeof(head)];
                Byte cpyByte[(h%24)*n];
                memcpy(cpyByte, newPixels+(24*n*i), (h%24)*n);
                [dataM appendBytes:&cpyByte length:sizeof(cpyByte)];
            }
            
            
        }
        else
        {
            head[6]=0x18;
            [dataM appendBytes:&head length:sizeof(head)];
            Byte cpyByte[24*n];
            memcpy(cpyByte, newPixels+(24*n*i), 24*n);
            [dataM appendBytes:&cpyByte length:sizeof(cpyByte)];
            
        }
    }
    
    
    
    
    
    
    
    //3.通过处理后的像素来重新得到新的图片
    
    //直接返回像素数据会跟合适
    
    return dataM;
}



+(uint8_t *)imgToGreyImage:(UIImage *)image {
    int kRed = 1;
    int kGreen = 2;
    int kBlue = 4;

    int colors = kGreen | kBlue | kRed;

    CGFloat actualWidth = image.size.width;
    CGFloat actualHeight = image.size.height;
    NSLog(@"actual size: %f,%f",actualWidth,actualHeight);
    uint32_t *rgbImage = (uint32_t *) malloc(actualWidth * actualHeight * sizeof(uint32_t));
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rgbImage, actualWidth, actualHeight, 8, actualWidth*4, colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextSetShouldAntialias(context, NO);
    CGContextDrawImage(context, CGRectMake(0, 0, actualWidth, actualHeight), [image CGImage]);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
     //now convert to grayscale
    uint8_t *m_imageData = (uint8_t *) malloc(actualWidth * actualHeight);
    for(int y = 0; y < actualHeight; y++) {
        for(int x = 0; x < actualWidth; x++) {
            uint32_t rgbPixel=rgbImage[(int)(y*actualWidth+x)];
            uint32_t sum=0,count=0;
            if (colors & kRed) {sum += (rgbPixel>>24)&255; count++;}
            if (colors & kGreen) {sum += (rgbPixel>>16)&255; count++;}
            if (colors & kBlue) {sum += (rgbPixel>>8)&255; count++;}
            m_imageData[(int)(y*actualWidth+x)]=sum/count;
        }
    }
    return m_imageData;
}

+ (UIImage *)imgWithImage:(UIImage *)image scaledToFillSize:(CGSize)size
{
    CGFloat scale = MAX(size.width/image.size.width, size.height/image.size.height);
    CGFloat width = image.size.width * scale;
    CGFloat height = image.size.height * scale;
    CGRect imageRect = CGRectMake((size.width - width)/2.0f,
                                  (size.height - height)/2.0f,
                                  width,
                                  height);
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [image drawInRect:imageRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

+ (NSData*)imgBitmapToArray:(UIImage*) bmp
{
    CGDataProviderRef provider = CGImageGetDataProvider(bmp.CGImage);
    NSData* data = (id)CFBridgingRelease(CGDataProviderCopyData(provider));
    return data;
}

/**
 **Raster Image - $1D $76 $30 m xL xH yL yH d1...dk
 Prints a raster image
 
 Format:
 Hex       $1D  $76 30  m xL xH yL yH d1...dk
 
 ASCII     GS   v   %   m xL xH yL yH d1...dk
 
 Decimal   29  118  48  m xL xH yL yH d1...dk
 
 Notes:
 When ​standard mode​ is enabled, this command is only executed when there is no data in the print buffer. (Line is empty)
 The defined data (​d​) defines each byte of the raster image. Each bit in every byte defines a pixel. A bit set to 1 is printed and a bit set to 0 is not printed.
 If a raster bit image exceeds one line, the excess data is not printed.
 This command feeds as much paper as is required to print the entire raster bit image, regardless of line spacing defined by 1/6” or 1/8” commands.
 After the raster bit image is printed, the print position goes to the beginning of the line.
 The following commands have no effect on a raster bit image:
 Emphasized
 Double Strike
 Underline
 White/Black Inverse Printing
 Upside-Down Printing
 Rotation
 Left margin
 Print Area Width
 A raster bit image data is printed in the following order:
 d1    d2    …    dx
 dx + 1    dx + 2    …    dx * 2
 .    .    .    .
 …    dk - 2    dk - 1    dk
 Defines and prints a raster bit image using the mode specified by ​m​:
 m    Mode    Width Scalar    Heigh Scalar
 0, 48    Normal    x1    x1
 1, 49    Double Width    x2    x1
 2, 50    Double Height    x1    x2
 3, 51    Double Width/Height    x2    x2
 xL, xH ​defines the raster bit image in the horizontal direction in ​bytes​ using two-byte number definitions. (​xL + (xH * 256)) Bytes
 yL, yH ​defines the raster bit image in the vertical direction in ​dots​ using two-byte number definitions. (​yL + (yH * 256)) Dots
 d ​ specifies the bit image data in raster format.
 k ​indicates the number of bytes in the bit image. ​k ​is not transmitted and is there for explanation only.
 **/
+ (NSData *)convertEachLinePixToCmd:(unsigned char *)src nWidth:(NSInteger) nWidth nHeight:(NSInteger) nHeight nMode:(NSInteger) nMode
{
    NSLog(@"SIZE OF SRC: %lu",sizeof(&src));
    NSInteger nBytesPerLine = (int)nWidth/8;
    unsigned char * data = malloc(nHeight*(8+nBytesPerLine));
    NSInteger k = 0;
    for(int i=0;i<nHeight;i++){
        NSInteger var10 = i*(8+nBytesPerLine);
         //GS v 0 m xL xH yL yH d1....dk 打印光栅位图
                data[var10 + 0] = 29;//GS
                data[var10 + 1] = 118;//v
                data[var10 + 2] = 48;//0
                data[var10 + 3] =  (unsigned char)(nMode & 1);
                data[var10 + 4] =  (unsigned char)(nBytesPerLine % 256);//xL
                data[var10 + 5] =  (unsigned char)(nBytesPerLine / 256);//xH
                data[var10 + 6] = 1;//yL
                data[var10 + 7] = 0;//yH
        
        for (int j = 0; j < nBytesPerLine; ++j) {
            data[var10 + 8 + j] = (int) (p_0[src[k]] + p_1[src[k + 1]] + p_2[src[k + 2]] + p_3[src[k + 3]] + p_4[src[k + 4]] + p_5[src[k + 5]] + p_6[src[k + 6]] + src[k + 7]);
            k =k+8;
        }
    }
    return [NSData dataWithBytes:data length:nHeight*(8+nBytesPerLine)];
}

+(unsigned char *)img_format_K_threshold:(unsigned char *) orgpixels
                        width:(NSInteger) xsize height:(NSInteger) ysize
{
    unsigned char * despixels = malloc(xsize*ysize);
    int graytotal = 0;
    int k = 0;
    
    int i;
    int j;
    int gray;
    for(i = 0; i < ysize; ++i) {
        for(j = 0; j < xsize; ++j) {
            gray = orgpixels[k] & 255;
            graytotal += gray;
            ++k;
        }
    }
    
    int grayave = graytotal / ysize / xsize;
    k = 0;
    for(i = 0; i < ysize; ++i) {
        for(j = 0; j < xsize; ++j) {
            gray = orgpixels[k] & 255;
            if(gray > grayave) {
                despixels[k] = 0;
            } else {
                despixels[k] = 1;
               // oneCount++;
            }
            
            ++k;
        }
    }
    return despixels;
}
+(NSData *)imgPixToTscCmd:(uint8_t *)src width:(NSInteger) width
{
    int length = (int)width/8;
    uint8_t * data = malloc(length);
    int k = 0;
    for(int j = 0;k<length;++k){
        data[k] =(uint8_t)(p_0[src[j]] + p_1[src[j + 1]] + p_2[src[j + 2]] + p_3[src[j + 3]] + p_4[src[j + 4]] + p_5[src[j + 5]] + p_6[src[j + 6]] + src[j + 7]);
        j+=8;
    }
    return [[NSData alloc] initWithBytes:data length:length];
}

+ (UIImage*)imgPadLeft:(NSInteger) left withSource: (UIImage*)source
{
    CGSize orgSize = [source size];
    CGSize size = CGSizeMake(orgSize.width + [[NSNumber numberWithInteger: left] floatValue], orgSize.height);
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context,
                                   [[UIColor whiteColor] CGColor]);
    CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    [source drawInRect:CGRectMake(left, 0, orgSize.width, orgSize.height)
             blendMode:kCGBlendModeNormal alpha:1.0];
    UIImage *paddedImage =  UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return paddedImage;
}


@end
