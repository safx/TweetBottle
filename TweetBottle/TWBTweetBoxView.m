//
//  TWBTweetBoxView.m
//  TweetBottle
//
//  Created by Safx Developer on 2014/01/12.
//  Copyright (c) 2014年 Safx Developers. All rights reserved.
//

#import "TWBTweetBoxView.h"
#import <SDWebImageDownloader.h>
#import <LEColorPicker.h>

@interface TWBTweetBoxView ()
@property UIImage* profileImage;
@end

@implementation TWBTweetBoxView

- (id)initWithFrame:(CGRect)frame tweet:(NSString*)tweet profileImageURL:(NSURL*)profileImageURL
{
    self = [super initWithFrame:frame];
    if (self) {
        NSAssert(tweet && profileImageURL, @"should be non-nil");
        // Initialization code
        _tweet = tweet;
        _profileImageURL = profileImageURL;

        self.backgroundColor = [UIColor colorWithWhite:0.7 alpha:1];
        self.tintColor = UIColor.whiteColor;
        
        [SDWebImageDownloader.sharedDownloader downloadImageWithURL:profileImageURL
                                                            options:0
                                                           progress:^(NSUInteger receivedSize, long long expectedSize) {}
                                                          completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
                                                              if (image && finished) {
                                                                  self.profileImage = image;
                                                                  LEColorPicker* picker = LEColorPicker.alloc.init;
                                                                  LEColorScheme* scheme = [picker colorSchemeFromImage:image];
                                                                  self.backgroundColor = scheme.backgroundColor;
                                                                  self.tintColor = UIColor.redColor; //scheme.primaryTextColor;
                                                                  [self setNeedsDisplay];
                                                              }
                                                          }];
    }
    return self;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    CGRect imageRect = CGRectMake(5, 5, 20, 20);
    [self.profileImage drawInRect:imageRect];
    
    UIFont* font = [UIFont systemFontOfSize:12];
    NSMutableParagraphStyle* style = NSParagraphStyle.defaultParagraphStyle.mutableCopy;
    style.lineBreakMode = NSLineBreakByCharWrapping;
    style.alignment = NSTextAlignmentLeft;
    NSDictionary* dic = @{NSFontAttributeName:font,
                          NSForegroundColorAttributeName:self.tintColor,
                          NSParagraphStyleAttributeName:style
                          };
    
    CGRect textRect = CGRectMake(30, 5, rect.size.width - 35, rect.size.height - 5);
    [self.tweet drawInRect:textRect withAttributes:dic];
}

@end
