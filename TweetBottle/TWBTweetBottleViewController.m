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
@property NSArray* queue;
@property NSString* sinceID;
@property NSUInteger count;
@property NSOperationQueue* operationQueue;
@property NSArray* topicIDs;

@property UIDynamicAnimator* animator;
@property UIGravityBehavior* gravity;
@property UICollisionBehavior* collision;
@property UIDynamicItemBehavior* dynamicProperties;
@property BOOL hiddenBottomBoundary;

@property NSString* accessToken;
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
    
    // Typetalk OAuth
    NSString *clientId = @"<Your Client ID>";
    NSString *clientSecret = @"<Your Client Secret>";
    
    _operationQueue = [[NSOperationQueue alloc] init];
    NSURL *url = [NSURL URLWithString:@"https://typetalk.in/oauth2/access_token"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.HTTPBody = [[NSString stringWithFormat:@"client_id=%@&client_secret=%@&grant_type=client_credentials&scope=my,topic.read", clientId, clientSecret] dataUsingEncoding:NSUTF8StringEncoding];

    [NSURLConnection sendAsynchronousRequest:req queue:_operationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        NSError* err = nil;
        NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
        if (!err) {
            _accessToken = json[@"access_token"];
            
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://typetalk.in/api/v1/topics"]];
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
            [req setValue:[NSString stringWithFormat:@"Bearer %@", _accessToken] forHTTPHeaderField:@"Authorization"];
            [NSURLConnection sendAsynchronousRequest:req queue:_operationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                NSDictionary* jsonData = [NSJSONSerialization
                                          JSONObjectWithData:data
                                          options:NSJSONReadingAllowFragments error:&error];
                if (error) {
                    NSLog(@"%@", error);
                    return;
                }
                
                if (jsonData) {
                    _topicIDs = [jsonData valueForKeyPath:@"topics.topic.id"];
                    dispatch_after(DISPATCH_TIME_NOW, dispatch_get_main_queue(), ^(void){
                        [NSTimer scheduledTimerWithTimeInterval:6 target:self selector:@selector(onTimer) userInfo:nil repeats:YES];
                    });
                }
            }];
        }
    }];
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
        
        NSString* tweet  = [dic valueForKeyPath:@"message"];
        NSString* urlstr = [dic valueForKeyPath:@"account.imageUrl"];

        NSURL* url = [NSURL URLWithString:urlstr];

        UIControl* box = [TWBTweetBoxView.alloc initWithFrame:rect tweet:tweet profileImageURL:url];
        box.transform = CGAffineTransformMakeRotation(rand() % 180);
        [box addTarget:self action:@selector(removeItem:) forControlEvents:UIControlEventTouchDown];
        
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
    if (_accessToken) {
        for (NSString* i in _topicIDs) {
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://typetalk.in/api/v1/topics/%@", i]];
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
            // TODO: add parameter "from"
            [req setValue:[NSString stringWithFormat:@"Bearer %@", _accessToken] forHTTPHeaderField:@"Authorization"];
            [NSURLConnection sendAsynchronousRequest:req queue:_operationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                NSDictionary* jsonData = [NSJSONSerialization
                                          JSONObjectWithData:data
                                          options:NSJSONReadingAllowFragments error:&error];
                if (error) {
                    NSLog(@"%@", error);
                    return;
                }
                
                if (jsonData) {
                    NSArray* array = [jsonData valueForKey:@"posts"];
                    @synchronized(self) {
                        self.queue = Underscore.flatten(@[array, self.queue]);
                    }
                    
                    dispatch_after(DISPATCH_TIME_NOW, dispatch_get_main_queue(), ^(void){
                        [self addTweetsIfNeeded];
                    });
                }
            }];
        }
    }
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
