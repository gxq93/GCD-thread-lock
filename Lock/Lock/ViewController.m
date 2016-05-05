//
//  ViewController.m
//  Lock
//
//  Created by 顾昕琪 on 16/5/5.
//  Copyright © 2016年 GuYi. All rights reserved.
//

#import "ViewController.h"
#import <libkern/OSAtomic.h>
@interface ViewController ()
{
    NSMutableArray *imageName;
    NSMutableArray *imageView;
    
    NSRecursiveLock *lock;
    OSSpinLock spinlock;
    dispatch_semaphore_t semaphore;
}
@end

static const NSString *urlStr = @"http://cdn.nshipster.com/images/the-nshipster-fake-book-cover@2x.png";
static const NSInteger imageCount = 15;
static const NSInteger limitCount = 7;
#define height [UIScreen mainScreen].bounds.size.height/5
#define width [UIScreen mainScreen].bounds.size.width/3

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self layoutUI];
    
}

//界面部署
- (void)layoutUI {
    imageView = [NSMutableArray arrayWithCapacity:imageCount];
    for (int y=0; y<5; y++) {
        for (int x=0; x<3; x++) {
            UIImageView *image = [[UIImageView alloc]initWithFrame:CGRectMake(x*width, y*height, width, height)];
            [self.view addSubview:image];
            [imageView addObject:image];
        }
    }
    
    imageName = [NSMutableArray arrayWithCapacity:imageCount];
    for (int i=0; i<imageCount; i++) {
        [imageName addObject:urlStr];
    }
    lock = [[NSRecursiveLock alloc]init];
    spinlock = OS_SPINLOCK_INIT;
    semaphore = dispatch_semaphore_create(1);

    UIButton *clearbutton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 100, 30)];
    clearbutton.backgroundColor = [UIColor grayColor];
    [clearbutton setCenter:CGPointMake(self.view.center.x, 50)];
    [clearbutton setTitle:@"清除" forState:UIControlStateNormal];
    [clearbutton addTarget:self action:@selector(clearTap) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:clearbutton];
    
    UIButton *serialbutton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 100, 30)];
    serialbutton.backgroundColor = [UIColor grayColor];
    [serialbutton setCenter:CGPointMake(self.view.center.x, 100)];
    [serialbutton setTitle:@"串行" forState:UIControlStateNormal];
    [serialbutton addTarget:self action:@selector(serialTap) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:serialbutton];
    
    UIButton *currentbutton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 100, 30)];
    currentbutton.backgroundColor = [UIColor grayColor];
    [currentbutton setCenter:CGPointMake(self.view.center.x, 150)];
    [currentbutton setTitle:@"并行" forState:UIControlStateNormal];
    [currentbutton addTarget:self action:@selector(currentTap) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:currentbutton];
    
    UIButton *syncbutton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 100, 30)];
    syncbutton.backgroundColor = [UIColor grayColor];
    [syncbutton setCenter:CGPointMake(self.view.center.x, 200)];
    [syncbutton setTitle:@"sync" forState:UIControlStateNormal];
    [syncbutton addTarget:self action:@selector(syncTap) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:syncbutton];

    UIButton *unlockbutton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 100, 30)];
    unlockbutton.backgroundColor = [UIColor grayColor];
    [unlockbutton setCenter:CGPointMake(self.view.center.x, 250)];
    [unlockbutton setTitle:@"无锁" forState:UIControlStateNormal];
    [unlockbutton addTarget:self action:@selector(unlockTap) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:unlockbutton];
    
    UIButton *lockbutton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 100, 30)];
    lockbutton.backgroundColor = [UIColor grayColor];
    [lockbutton setCenter:CGPointMake(self.view.center.x, 300)];
    [lockbutton setTitle:@"有锁" forState:UIControlStateNormal];
    [lockbutton addTarget:self action:@selector(lockTap) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:lockbutton];
    
}

- (void)loadImageAtIndex:(NSInteger)index {
    //异步请求数据
    NSData *data = [self requestDataAtIndex:index];
    //切回主线程更新UI
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateWithData:data atIndex:index];
    });
}

- (NSData*)requestDataAtIndex:(NSInteger)index {
    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageName[index]]];
    return data;
}

- (void)updateWithData:(NSData*)data atIndex:(NSInteger)index {
    UIImageView *image = imageView[index];
    image.image = [UIImage imageWithData:data];
}

- (void)clearTap {
    for (int i=0; i<imageCount; i++) {
        UIImageView *image = imageView[i];
        image.image = nil;
    }
    [self layoutUI];
}

- (void)serialTap {
    dispatch_queue_t serial = dispatch_queue_create("serialQueue", DISPATCH_QUEUE_SERIAL);
    for (NSInteger i=0; i<imageCount; i++) {
        dispatch_async(serial, ^{
            [self loadImageAtIndex:i];
        });
    }
}

- (void)currentTap {
    for (NSInteger i=0; i<imageCount; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self loadImageAtIndex:i];
        });
    }
}

- (void)syncTap {
    for (NSInteger i=0; i<imageCount; i++) {
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self loadImageAtIndex:i];
        });
    }
}
#pragma mark - 如果只要显示9张图片
- (void)unlockTap {
    for (NSInteger i=0; i<imageCount; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self unlockloadImageAtIndex:i];
        });
    }
}

- (void)unlockloadImageAtIndex:(NSInteger)index {
    if (imageName.count>limitCount) {
        NSString *str = [imageName lastObject];
        NSData *data =[NSData dataWithContentsOfURL:[NSURL URLWithString:str]];
        [imageName removeLastObject];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImageView *image = imageView[index];
            image.image = [UIImage imageWithData:data];
        });
    }
}

- (void)lockTap {
    for (NSInteger i=0; i<imageCount; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self lockloadImageAtIndex:i];
        });
    }
}

- (void)lockloadImageAtIndex:(NSInteger)index {
    //加锁
//    [lock lock];
//    OSSpinLockLock(&spinlock);
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if (imageName.count>limitCount){
        NSString *str = [imageName lastObject];
        NSData *data =[NSData dataWithContentsOfURL:[NSURL URLWithString:str]];
        [imageName removeLastObject];

        dispatch_async(dispatch_get_main_queue(), ^{
            UIImageView *image = imageView[index];
            image.image = [UIImage imageWithData:data];
        });

    }
    //解锁
//    [lock unlock];
//    OSSpinLockUnlock(&spinlock);
    dispatch_semaphore_signal(semaphore);
}

@end
