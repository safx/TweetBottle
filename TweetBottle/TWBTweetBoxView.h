//
//  TWBTweetBoxView.h
//  TweetBottle
//
//  Created by Safx Developer on 2014/01/12.
//  Copyright (c) 2014年 Safx Developers. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TWBTweetBoxView : UIControl
@property (readonly) NSString* tweet;
@property (readonly) NSURL* profileImageURL;
- (id)initWithFrame:(CGRect)frame tweet:(NSString*)tweet profileImageURL:(NSURL*)profileImageURL;
@end
