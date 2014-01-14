//
//  TWBTweetBottleViewController.m
//  TweetBottle
//
//  Created by Safx Developer on 2014/01/12.
//  Copyright (c) 2014年 Safx Developers. All rights reserved.
//

#import "TWBTweetBottleViewController.h"
#import "TWBTweetBoxView.h"

@interface TWBTweetBottleViewController () <UICollisionBehaviorDelegate>
@property ACAccountStore* accountStore;
@property NSTimer* timer;
@property NSArray* queue;
@property NSString* sinceID;
@property NSUInteger count;

@property UIDynamicAnimator* animator;
@property UIGravityBehavior* gravity;
@property UICollisionBehavior* collision;
@property UIDynamicItemBehavior* dynamicProperties;
@property BOOL hiddenBottomBoundary;
@end

@implementation TWBTweetBottleViewController

- (id)init
{
    self = [super init];
    if (self) {
        // Custom initialization
        self.queue = @[];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    _accountStore = ACAccountStore.alloc.init;

    _animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    _gravity = UIGravityBehavior.alloc.init;
    _collision = UICollisionBehavior.alloc.init;
    _dynamicProperties = UIDynamicItemBehavior.alloc.init;
    _dynamicProperties.density = 1;
    _dynamicProperties.elasticity = 0;
    _dynamicProperties.friction = 0.2;
    _dynamicProperties.angularResistance = TRUE;

    _collision.collisionDelegate = self;

    [self addBoundaries];
    
    [_animator addBehavior:_gravity];
    [_animator addBehavior:_collision];
    [_animator addBehavior:_dynamicProperties];
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:6 target:self selector:@selector(onTimer) userInfo:nil repeats:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -

- (void)onTimer {
    if (_count % 10 == 0) {
        NSLog(@"fetch");
        [self fetchTimeline];
    } else {
        [self addTweetsIfNeeded];
    }
    ++_count;
}

- (void)addTweetsIfNeeded {
    int TW = 140, TH = 70;
    int y = -300;

    for (int t = 0; t < 10; ++t, y -= TW*4/3) {
        NSDictionary* dic = nil;
        @synchronized(self) {
            dic = _queue.lastObject;
            _queue = Underscore.head(_queue, _queue.count - 1);
        }
        if (!dic) return;
        
        CGSize s = self.view.frame.size;
        CGFloat w = s.width;
        CGRect rect = CGRectMake(rand() % ((int)w-TW), y, TW, TH);
        
        NSString* tweet  = [dic valueForKeyPath:@"text"];
        NSString* urlstr = [dic valueForKeyPath:@"user.profile_image_url"];

        NSURL* url = [NSURL URLWithString:urlstr];

        UIView* box = [TWBTweetBoxView.alloc initWithFrame:rect tweet:tweet profileImageURL:url];
        box.transform = CGAffineTransformMakeRotation(rand() % 180);
        
        [self.view addSubview:box];
        [_gravity addItem:box];
        [_collision addItem:box];
        [_dynamicProperties addItem:box];
    }
}

- (void)addBoundaries {
    CGSize s = self.view.frame.size;
    CGFloat w = s.width;
    CGFloat h = s.height;
    
    _hiddenBottomBoundary = FALSE;
    
    [_collision addBoundaryWithIdentifier:@"bottom"
                                fromPoint:CGPointMake(0, h)
                                  toPoint:CGPointMake(w, h)];
    
    [_collision addBoundaryWithIdentifier:@"left"
                                fromPoint:CGPointMake(0, -9999)
                                  toPoint:CGPointMake(0, h)];
    
    [_collision addBoundaryWithIdentifier:@"right"
                                fromPoint:CGPointMake(w, -9999)
                                  toPoint:CGPointMake(w, h)];
    
    [_collision addBoundaryWithIdentifier:@"outer-edge"
                                fromPoint:CGPointMake(-9999, h + 10)
                                  toPoint:CGPointMake(9999+w, h + 10)];
}

#pragma mark - Social Framework

- (void)fetchTimeline {
    ACAccountType* accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [self.accountStore requestAccessToAccountsWithType:accountType
                                           options:NULL
                                        completion:^(BOOL granted, NSError* error) {
         if (error) {
             NSLog(@"%@", error);
             return;
         }
         
         NSArray* accounts = [self.accountStore accountsWithAccountType:accountType];
         if (accounts.count == 0) return;
         
         NSURL* url = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/home_timeline.json"];
         NSDictionary* params = @{@"screen_name" : [accounts.firstObject username],
                                  @"count" : @"60" };
         if (self.sinceID) {
             params = Underscore.extend(params, @{ @"since_id": self.sinceID });
         }
                                            
         SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                 requestMethod:SLRequestMethodGET
                                                           URL:url
                                                    parameters:params];
         
         request.account = accounts.firstObject;
         [request performRequestWithHandler:^(NSData* responseData,
                                              NSHTTPURLResponse* urlResponse,
                                              NSError* error) {
             if (error) {
                 NSLog(@"%@, %@", urlResponse, error);
                 return;
             }
             
             if (200 <= urlResponse.statusCode && urlResponse.statusCode < 300) {
                 NSError* e = nil;
                 NSArray* jsonData = [NSJSONSerialization
                                      JSONObjectWithData:responseData
                                      options:NSJSONReadingAllowFragments error:&e];
                 if (e) {
                     NSLog(@"%@", e);
                     return;
                 }

                 if (jsonData.count > 0) {
                     self.sinceID = [jsonData.firstObject valueForKeyPath:@"id_str"];
                     @synchronized(self) {
                         self.queue = Underscore.flatten(@[jsonData, self.queue]);
                     }
                     
                     dispatch_after(DISPATCH_TIME_NOW, dispatch_get_main_queue(), ^(void){
                         [self addTweetsIfNeeded];
                     });
                 }
             } else {
                 NSLog(@"%@", urlResponse);
             }
         }];
     }];
}

#pragma mark - UICollisionBehaviorDelegate

- (void)removeItem:(UIView*)item {
    [item removeFromSuperview];
    [_gravity removeItem:item];
    [_collision removeItem:item];
    [_dynamicProperties removeItem:item];
}

- (void)collisionBehavior:(UICollisionBehavior *)behavior beganContactForItem:(id<UIDynamicItem>)item
   withBoundaryIdentifier:(id<NSCopying>)identifier atPoint:(CGPoint)p {
    if ([(NSString*) identifier isEqualToString:@"outer-edge"]) {
        [self removeItem:(UIView*)item];
    }
}

- (void)collisionBehavior:(UICollisionBehavior *)behavior beganContactForItem:(id<UIDynamicItem>)item1 withItem:(id<UIDynamicItem>)item2 atPoint:(CGPoint)p {
    if (p.y > 100 || _hiddenBottomBoundary) return;
    
    _hiddenBottomBoundary = TRUE;
    [_collision removeBoundaryWithIdentifier:@"bottom"];
    
    double delayInSeconds = fmin(0.8, fmax(0.2, - p.y * 0.01));
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self addBoundaries];
    });
}

@end
