//
//  TrendingViewController.m
//  PigHub
//
//  Created by Rainbow on 2016/12/19.
//  Copyright © 2016年 PizzaLiu. All rights reserved.
//

#import "TrendingViewController.h"
#import "SegmentBarView.h"
#import "LanguageViewController.h"
#import "LanguageModel.h"
#import "WeakifyStrongify.h"
#import "MJRefresh.h"
#import "DataEngine.h"
#import "RepositoryModel.h"
#import "RepositoryTableViewCell.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import "RepositoryDetailViewController.h"
#import "UserModel.h"

NSString * const SelectedLangQueryPrefKey = @"TrendingSelectedLangPrefKey";

@interface TrendingViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet SegmentBarView *segmentBar;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *sinceSigmentBar;
@property (weak, nonatomic) IBOutlet UILabel *noticeLabel;
@property (weak, nonatomic) UIImageView *navHairline;

@property (strong, nonatomic) NSArray<RepositoryModel *> *tableData;
@property (strong, nonatomic) Language *targetLanguage;

@property (strong, nonatomic) NSString *sinceStr;

@end

@implementation TrendingViewController

+ (void)initialize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *factorySettings = @{SelectedLangQueryPrefKey: @""};

    [defaults registerDefaults:factorySettings];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navHairline = [self findNavBarHairline];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *selectedLangQuery = [defaults objectForKey: SelectedLangQueryPrefKey];
    if (selectedLangQuery) {
        Language *selectedLang = [[LanguagesModel sharedStore] languageForQuery:selectedLangQuery];
        if (selectedLang) {
            self.targetLanguage = selectedLang;
        }
    }

    if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)]) {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    self.tableView.contentInset = UIEdgeInsetsMake(104, 0, 48, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(104, 0, 48, 0);

    //[self.tableView registerClass:[RepositoryTableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];

    UINib *nib = [UINib nibWithNibName:@"RepositoryTableViewCell" bundle:nil];
    [self.tableView registerNib:nib forCellReuseIdentifier:@"UITableViewCell"];

    [self initRefresh];
}

- (UIBarPosition)positionForBar:(id<UIBarPositioning>)bar
{
    return UIBarPositionTopAttached;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.tableView.delegate = self;

    if (self.segmentBar.alpha > 0) {
        [self.navHairline setHidden:YES];
    } else {
        [self.navHairline setHidden:NO];
    }

    if (self.targetLanguage) {
        self.navigationItem.title = self.targetLanguage.name;
    }

    self.noticeLabel.hidden = YES;

}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    [self.navHairline setHidden:NO];
    self.tableView.delegate = nil;

    __weak UIViewController *desVc = segue.destinationViewController;
    if ([segue.identifier isEqualToString:@"LanguageSelector"]) {
        LanguageViewController *lvc = (LanguageViewController *)desVc;
        lvc.selectedLanguageQuery = self.targetLanguage.query;

        weakify(self);
        lvc.dismissBlock = ^(Language *selectedLang){
            strongify(self);
            if (![self.targetLanguage.query isEqualToString:selectedLang.query]) {
                self.targetLanguage = selectedLang;
                self.tableData = nil;
                [self.tableView reloadData];
                [self.tableView.mj_header beginRefreshing];
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:selectedLang.query forKey:SelectedLangQueryPrefKey];
            }
        };

        return ;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - tableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.tableData count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    RepositoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];
    RepositoryModel *repo = [self.tableData objectAtIndex:indexPath.row];

    cell.repo = repo;
    cell.orderLabel.text = [NSString stringWithFormat:@"%ld", (long)indexPath.row + 1];

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [RepositoryTableViewCell cellHeight];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    RepositoryModel *repo = [self.tableData objectAtIndex:indexPath.row];
    RepositoryDetailViewController *rdvc = [[RepositoryDetailViewController alloc] init];
    rdvc.repo = repo;
    rdvc.hidesBottomBarWhenPushed = YES;
    [self.navHairline setHidden:NO];
    [self.navigationController pushViewController:rdvc animated:YES];
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - navbar

- (UIImageView *)findNavBarHairline
{
    for (UIView *aView in self.navigationController.navigationBar.subviews) {
        for (UIView *bView in aView.subviews) {
            if ([bView isKindOfClass:[UIImageView class]] &&
                bView.bounds.size.width == self.navigationController.navigationBar.frame.size.width &&
                bView.bounds.size.height < 2) {
                return (UIImageView *)bView;
            }
        }
    }

    return nil;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat offsetY = scrollView.contentOffset.y + self.tableView.contentInset.top;
    CGFloat panTranslationY = [scrollView.panGestureRecognizer translationInView:self.tableView].y;
    if (offsetY > 40) {
        // show in down scroll
        if (panTranslationY > 0) {
            [UIView animateWithDuration:0.5 animations:^{
                [self.segmentBar setAlpha:1.0];
                [self.navHairline setHidden:YES];
            }];
        }
        // hide in up scroll
        else {
            [UIView animateWithDuration:0.5 animations:^{
                [self.segmentBar setAlpha:0.0];
                [self.navHairline setHidden:NO];
            }];
        }
    } else {
        [self.navHairline setHidden:YES];
        [self.segmentBar setAlpha:1.0];
    }
}

#pragma mark - refresh

- (void)initRefresh
{
    __weak UITableView *tableView = self.tableView;
    weakify(self);
    tableView.mj_header = [MJRefreshNormalHeader headerWithRefreshingBlock:^{

        strongify(self);
        self.noticeLabel.hidden = YES;
        [[DataEngine sharedEngine] getTrendingDataWithSince:self.sinceStr lang:self.targetLanguage.query isDeveloper:NO completionHandler:^(NSArray<RepositoryModel *> *repositories, NSError *error) {
            if (error) {
                self.noticeLabel.text = NSLocalizedString(@"error occured in loading data", @"");
                self.noticeLabel.hidden = NO;
            } else if ([repositories count] <= 0) {
                self.noticeLabel.text = NSLocalizedString(@"no relatived data or being dissected", @"");
                self.noticeLabel.hidden = NO;
            }
            self.tableData = repositories;
            [self.tableView reloadData];
            [tableView.mj_header endRefreshing];
        }];

    }];

    self.tableView.mj_footer = [MJRefreshBackNormalFooter footerWithRefreshingTarget:self refreshingAction:nil];
    [tableView.mj_footer endRefreshingWithNoMoreData];

    tableView.mj_header.automaticallyChangeAlpha = YES;
    ((MJRefreshNormalHeader *)tableView.mj_header).lastUpdatedTimeLabel.hidden = YES;

    [tableView.mj_header beginRefreshing];
}

#pragma mark - segmentbar

- (IBAction)sinceSegmentChange:(id)sender {
    static NSArray *sinces;
    if (!sinces) {
        sinces = @[NSLocalizedString(@"daily", @""),
                   NSLocalizedString(@"weekly", @""),
                   NSLocalizedString(@"monthly", @"")
                   ];
    }
    NSInteger index = [sender selectedSegmentIndex];
    self.sinceStr = sinces[index];
    [self.tableView.mj_header beginRefreshing];
}

@end
