//
//  VVeboTableView.m
//  VVeboTableViewDemo
//
//  Created by Johnil on 15/5/25.
//  Copyright (c) 2015年 Johnil. All rights reserved.
//

#import "VVeboTableView.h"
#import "NSString+Additions.h"
#import "UIScreen+Additions.h"
#import "VVeboTableViewCell.h"
#import "UIView+Additions.h"
@interface VVeboTableView() <UITableViewDelegate, UITableViewDataSource>

@end

@implementation VVeboTableView{
    NSMutableArray *datas;
    NSMutableArray *needLoadArr;
    BOOL scrollToToping;
}

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style{
    self = [super initWithFrame:frame style:style];
    if (self) {
        self.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.dataSource = self;
        self.delegate = self;
        datas = [[NSMutableArray alloc] init];
        needLoadArr = [[NSMutableArray alloc] init];
        
        [self loadData];
        [self reloadData];
    }
    return self;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return datas.count;
}

- (NSInteger)numberOfSections{
    return 1;
}

- (void)drawCell:(VVeboTableViewCell *)cell withIndexPath:(NSIndexPath *)indexPath{
    NSDictionary *data = [datas objectAtIndex:indexPath.row];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    // 清除数据
    [cell clear];
    // 加载数据
    cell.data = data;
    
    // 这个判读和scrollViewWillEndDragging配合使用，如果needLoad数组有数据，说明是快速滚动，中间的Cell就不要绘制了
    if (needLoadArr.count>0&&[needLoadArr indexOfObject:indexPath]==NSNotFound) {
        // 清除数据
        [cell clear];
        return;
    }
    
    // 滚到顶部，Cell也不加载数据，直接返回
    if (scrollToToping) {
        return;
    }
    [cell draw];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    VVeboTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell==nil) {
        cell = [[VVeboTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:@"cell"];
    }
    [self drawCell:cell withIndexPath:indexPath];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSDictionary *dict = datas[indexPath.row];
    float height = [dict[@"frame"] CGRectValue].size.height;
//    NSLog(@"%f", height);
    return height;
}

// 开始滚动，把needLoadArr清空
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    [needLoadArr removeAllObjects];
}

// 按需加载 - 如果目标行与当前行相差超过指定行数，只在目标滚动范围的前后指定3行加载。
// 准备停止滚动时，触发方法
// 按需加载的意思是，当快速滚动时，中间滚动过的Cell就不要加载数据的了，当快要停止滚动到达目标范围Cell时，在前后指定3行加载
// 不是快速滚动，这个方法就不会加载三行
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset{
    // 获取将要滚动到目标点的 Cell的 IndexPath
    NSIndexPath *ip = [self indexPathForRowAtPoint:CGPointMake(0, targetContentOffset->y)];
    // 获取没滚动前显示的所有Cell的IndexPath
    NSIndexPath *cip = [[self indexPathsForVisibleRows] firstObject];
    
    // 指定行数
    NSInteger skipCount = 8;
    
    // 如果目标IndexPath和当前显示的IndexPath相差超过8（因为可能向上或向下滚动，所有取绝对值labs）
    if (labs(cip.row-ip.row)>skipCount) {
        // 获取目标范围要显示的IndexPath数组
        NSArray *temp = [self indexPathsForRowsInRect:CGRectMake(0, targetContentOffset->y, self.width, self.height)];
        NSMutableArray *arr = [NSMutableArray arrayWithArray:temp];
        
        // 向上
        if (velocity.y<0) {
            // 快到目标滚动范围，在范围的底部多加载3行数据来显示，滚到目标范围后，那3行可能超出了屏幕范围
            NSIndexPath *indexPath = [temp lastObject];
            // 不要超过总数据范围（超过总数据范围不太可能发生）
            if (indexPath.row+3<datas.count) {
                [arr addObject:[NSIndexPath indexPathForRow:indexPath.row+1 inSection:0]];
                [arr addObject:[NSIndexPath indexPathForRow:indexPath.row+2 inSection:0]];
                [arr addObject:[NSIndexPath indexPathForRow:indexPath.row+3 inSection:0]];
            }
        }
        // 向下
        else {
            // 在目标滚动范围的顶部添加3行数据
            NSIndexPath *indexPath = [temp firstObject];
            // 确保row > 3，否则越界了
            if (indexPath.row>3) {
                [arr addObject:[NSIndexPath indexPathForRow:indexPath.row-3 inSection:0]];
                [arr addObject:[NSIndexPath indexPathForRow:indexPath.row-2 inSection:0]];
                [arr addObject:[NSIndexPath indexPathForRow:indexPath.row-1 inSection:0]];
            }
        }
        // 添加到needLoad数组
        [needLoadArr addObjectsFromArray:arr];
    }
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView{
    scrollToToping = YES;
    return YES;
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView{
    scrollToToping = NO;
    [self loadContent];
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView{
    scrollToToping = NO;
    [self loadContent];
}

//用户触摸时第一时间加载内容，防止快速滚动后突然停下来，某些Cell没有draw，显示无内容
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
    // 不是滚动到顶部，清除needLoadArr
    if (!scrollToToping) {
        [needLoadArr removeAllObjects];
        [self loadContent];
    }
    return [super hitTest:point withEvent:event];
}

- (void)loadContent{
    if (scrollToToping) {
        return;
    }
    if (self.indexPathsForVisibleRows.count<=0) {
        return;
    }
    if (self.visibleCells&&self.visibleCells.count>0) {
        for (id temp in [self.visibleCells copy]) {
            VVeboTableViewCell *cell = (VVeboTableViewCell *)temp;
            [cell draw];
        }
    }
}

//读取信息
- (void)loadData{
    NSArray *temp = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"data" ofType:@"plist"]];
    for (NSDictionary *dict in temp) {
        NSDictionary *user = dict[@"user"];
        NSMutableDictionary *data = [NSMutableDictionary dictionary];
        data[@"avatarUrl"] = user[@"avatar_large"];
        data[@"name"] = user[@"screen_name"];
        NSString *from = [dict valueForKey:@"source"];
        if (from.length>6) {
            NSInteger start = [from indexOf:@"\">"]+2;
            NSInteger end = [from indexOf:@"</a>"];
            from = [from substringFromIndex:start toIndex:end];
        } else {
            from = @"未知";
        }
        data[@"time"] = @"2015-05-25";
        data[@"from"] = from;
        [self setCommentsFrom:dict toData:data];
        [self setRepostsFrom:dict toData:data];
        data[@"text"] = dict[@"text"];
        
        NSDictionary *retweet = [dict valueForKey:@"retweeted_status"];
        if (retweet) {
            NSMutableDictionary *subData = [NSMutableDictionary dictionary];
            NSDictionary *user = retweet[@"user"];
            subData[@"avatarUrl"] = user[@"avatar_large"];
            subData[@"name"] = user[@"screen_name"];
            subData[@"text"] = [NSString stringWithFormat:@"@%@: %@", subData[@"name"], retweet[@"text"]];
            [self setPicUrlsFrom:retweet toData:subData];
            
            {
                float width = [UIScreen screenWidth]-SIZE_GAP_LEFT*2;
                CGSize size = [subData[@"text"] sizeWithConstrainedToWidth:width fromFont:FontWithSize(SIZE_FONT_SUBCONTENT) lineSpace:5];
                NSInteger sizeHeight = (size.height+.5);
                subData[@"textRect"] = [NSValue valueWithCGRect:CGRectMake(SIZE_GAP_LEFT, SIZE_GAP_BIG, width, sizeHeight)];
                sizeHeight += SIZE_GAP_BIG;
                if (subData[@"pic_urls"] && [subData[@"pic_urls"] count]>0) {
                    sizeHeight += (SIZE_GAP_IMG+SIZE_IMAGE+SIZE_GAP_IMG);
                }
                sizeHeight += SIZE_GAP_BIG;
                subData[@"frame"] = [NSValue valueWithCGRect:CGRectMake(0, 0, [UIScreen screenWidth], sizeHeight)];
            }
            data[@"subData"] = subData;
        } else {
            [self setPicUrlsFrom:dict toData:data];
        }
        
        {
            float width = [UIScreen screenWidth]-SIZE_GAP_LEFT*2;
            CGSize size = [data[@"text"] sizeWithConstrainedToWidth:width fromFont:FontWithSize(SIZE_FONT_CONTENT) lineSpace:5];
            NSInteger sizeHeight = (size.height+.5);
            data[@"textRect"] = [NSValue valueWithCGRect:CGRectMake(SIZE_GAP_LEFT, SIZE_GAP_TOP+SIZE_AVATAR+SIZE_GAP_BIG, width, sizeHeight)];
            sizeHeight += SIZE_GAP_TOP+SIZE_AVATAR+SIZE_GAP_BIG;
            if (data[@"pic_urls"] && [data[@"pic_urls"] count]>0) {
                sizeHeight += (SIZE_GAP_IMG+SIZE_IMAGE+SIZE_GAP_IMG);
            }
            
            NSMutableDictionary *subData = [data valueForKey:@"subData"];
            if (subData) {
                sizeHeight += SIZE_GAP_BIG;
                CGRect frame = [subData[@"frame"] CGRectValue];
                CGRect textRect = [subData[@"textRect"] CGRectValue];
                frame.origin.y = sizeHeight;
                subData[@"frame"] = [NSValue valueWithCGRect:frame];
                textRect.origin.y = frame.origin.y+SIZE_GAP_BIG;
                subData[@"textRect"] = [NSValue valueWithCGRect:textRect];
                sizeHeight += frame.size.height;
                data[@"subData"] = subData;
            }
            
            sizeHeight += 30;
            data[@"frame"] = [NSValue valueWithCGRect:CGRectMake(0, 0, [UIScreen screenWidth], sizeHeight)];
        }
        
        [datas addObject:data];
    }
}

- (void)setCommentsFrom:(NSDictionary *)dict toData:(NSMutableDictionary *)data{
    NSInteger comments = [dict[@"reposts_count"] integerValue];
    if (comments>=10000) {
        data[@"reposts"] = [NSString stringWithFormat:@"  %.1fw", comments/10000.0];
    } else {
        if (comments>0) {
            data[@"reposts"] = [NSString stringWithFormat:@"  %ld", (long)comments];
        } else {
            data[@"reposts"] = @"";
        }
    }
}

- (void)setRepostsFrom:(NSDictionary *)dict toData:(NSMutableDictionary *)data{
    NSInteger comments = [dict[@"comments_count"] integerValue];
    if (comments>=10000) {
        data[@"comments"] = [NSString stringWithFormat:@"  %.1fw", comments/10000.0];
    } else {
        if (comments>0) {
            data[@"comments"] = [NSString stringWithFormat:@"  %ld", (long)comments];
        } else {
            data[@"comments"] = @"";
        }
    }
}

- (void)setPicUrlsFrom:(NSDictionary *)dict toData:(NSMutableDictionary *)data{
    NSArray *pic_urls = [dict valueForKey:@"pic_urls"];
    NSString *url = [dict valueForKey:@"thumbnail_pic"];
    NSArray *pic_ids = [dict valueForKey:@"pic_ids"];
    if (pic_ids && pic_ids.count>1) {
        NSString *typeStr = @"jpg";
        if (pic_ids.count>0||url.length>0) {
            typeStr = [url substringFromIndex:url.length-3];
        }
        NSMutableArray *temp = [NSMutableArray array];
        for (NSString *pic_url in pic_ids) {
            [temp addObject:@{@"thumbnail_pic": [NSString stringWithFormat:@"http://ww2.sinaimg.cn/thumbnail/%@.%@", pic_url, typeStr]}];
        }
        data[@"pic_urls"] = temp;
    } else {
        data[@"pic_urls"] = pic_urls;
    }
}

- (void)removeFromSuperview{
    for (UIView *temp in self.subviews) {
        for (VVeboTableViewCell *cell in temp.subviews) {
            if ([cell isKindOfClass:[VVeboTableViewCell class]]) {
                [cell releaseMemory];
            }
        }
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [datas removeAllObjects];
    datas = nil;
    [self reloadData];
    self.delegate = nil;
    [needLoadArr removeAllObjects];
    needLoadArr = nil;
    [super removeFromSuperview];
}

@end
