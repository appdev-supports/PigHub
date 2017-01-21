//
//  Repository.m
//  PigHub
//
//  Created by Rainbow on 2017/1/8.
//  Copyright © 2017年 PizzaLiu. All rights reserved.
//

#import "Repository.h"
#import <UIKit/UIKit.h>

@implementation Repository

- (NSString *)avatarUrlForSize:(int)size
{
    int realSize = [UIScreen mainScreen].scale * size;
    return [NSString stringWithFormat:@"%@?s=%d", self.avatarUrl, realSize];
}

@end