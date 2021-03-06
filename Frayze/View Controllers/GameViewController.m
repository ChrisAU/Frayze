//
//  FirstViewController.m
//  Frayze
//
//  Created by CJNevin on 30/10/2013.
//  Copyright (c) 2013 CJNevin. All rights reserved.
//

//  TODO: Improvements
//  Dropping a tile should find closest neighbour if the tile is already occupied
//  Dragging from board should move tile to board superview
//  Prompt before committing settings changes
//  Better themes, actual theming
//  Gradients on tiles, squares, rack
//  Alternating colours in search results
//  Add additional languages, need dictionaries with definitions
//  CPU AI - difficulty levels based on length/score associated with a word

#import "GameViewController.h"
#import "UIScrollView+Directions.h"
#import "UIViewController+Keyboard.h"
#import <AudioToolbox/AudioServices.h>

@interface GameViewController ()
{
    NSUInteger currentScore;
    UIView *boardContainer;
    
    CNScrabble *scrabble;
}
@end

@implementation GameViewController

- (void)applyTheme
{
    tileRack.backgroundColor = [UIColor tileRackColor];
    cpuScoreLabel.textColor = [UIColor tileTextColor];
    cpuScoreHeadLabel.textColor = [UIColor tileTextColor];
    scoreLabel.textColor = [UIColor tileTextColor];
    scoreHeadLabel.textColor = [UIColor tileTextColor];
    [boardScroller.layer setBorderColor:[UIColor squareBorderColor].CGColor];
    [self.view setBackgroundColor:[UIColor gameBackgroundColor]];
    for (CNScrabbleSquare *square in boardContainer.subviews) {
        if ([square isKindOfClass:[CNScrabbleSquare class]]) {
            [square applyTheme];
        }
    }
    [tileRack.subviews makeObjectsPerformSelector:@selector(applyTheme)];
    [scrabble.playedTiles makeObjectsPerformSelector:@selector(applyTheme)];
    [scrabble.droppedTiles makeObjectsPerformSelector:@selector(applyTheme)];
    for (UIView *v in boardContainer.subviews) {
        if (v.tag == 101) {
            [v.layer setBorderColor:[UIColor tileHighlight].CGColor];
        }
    }
    if (latticeImage) {
        [latticeImage removeFromSuperview];
    }
    latticeImage = [[UIImageView alloc] initWithImage:[self createLattice]];
    [boardContainer addSubview:latticeImage];
}

- (UIImage*)createLattice
{
    CGFloat side = 600.f, step = side / 15.f;
    UIGraphicsBeginImageContext(CGSizeMake(side, side));
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 1);
    [[UIColor squareBorderColor] setStroke];
    for (NSInteger i = 0; i <= side; i+= step) {
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, i, 0);
        CGContextAddLineToPoint(context, i, side);
        CGContextStrokePath(context);
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, i);
        CGContextAddLineToPoint(context, side, i);
        CGContextStrokePath(context);
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)restoreNavigation:(BOOL)animated
{
    UIBarButtonItem *play = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"play"] style:UIBarButtonItemStyleBordered target:self action:@selector(playPressed:)];
    UIBarButtonItem *shuffle = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"shuffle"] style:UIBarButtonItemStyleBordered target:self action:@selector(shufflePressed:)];
    UIBarButtonItem *settings = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsPressed:)];
    UIBarButtonItem *info = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"visible"] style:UIBarButtonItemStyleBordered target:self action:@selector(infoPressed:)];
    UIBarButtonItem *search = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"magnifying_glass"] style:UIBarButtonItemStyleBordered target:self action:@selector(searchPressed:)];
    
    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];
    spacer.width = 20.f;
    [self.navigationItem setLeftBarButtonItems:@[settings, spacer, info, spacer, search] animated:animated];
    [self.navigationItem setRightBarButtonItems:@[play, spacer, shuffle] animated:animated];
    [self.navigationItem setTitle:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self registerKeyboard];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:) name:THEME_CHANGED object:nil];
    
    boardContainer = [[UIView alloc] init];
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapBoard:)];
    [doubleTap setNumberOfTapsRequired:2];
    [boardScroller addGestureRecognizer:doubleTap];
    [boardScroller addSubview:boardContainer];
    [boardScroller setDelegate:self];
    [boardScroller setMaximumZoomScale:1.0f];
    [boardScroller setMinimumZoomScale:0.5f];
    [boardScroller setBouncesZoom:NO];
    [boardScroller setScrollIndicatorInsets:UIEdgeInsetsZero];
    [boardScroller setContentInset:UIEdgeInsetsZero];
    [boardScroller.layer setBorderWidth:1.0f];
    
    // Create letters to pick
    NSUInteger row = 0, col = 0;
    for (char c = 'A'; c <= 'Z'; c++) {
        NSString *letter = [NSString stringWithFormat:@"%c", c];
        CNScrabbleTile *tile = [[CNScrabbleTile alloc] initWithFrame:CGRectMake(4 + (row * 44), 4 + (col * 44), 40, 40) letter:letter];
        [tile addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectLetter:)]];
        [selectTileView addSubview:tile];
        row++;
        if (row >= 6) {
            row = 0;
            col++;
        }
    }
    
    [self restoreNavigation:NO];
    [self.view bringSubviewToFront:tileRack];
    [self.view bringSubviewToFront:settingsView];
    
    settingsDataSource = [SettingsDataSource sharedInstance];
    settingsTable.dataSource = settingsDataSource;
    settingsTable.delegate = settingsDataSource;
    
    // Finally setup the scrabble board
    [self applyTheme];
    scrabble = [[CNScrabble alloc] initWithDelegate:self];
    [scrabble resetGame];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Scroll View

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    if (scrollView == boardScroller) {
        return boardContainer;
    }
    return nil;
}

#pragma mark - Delegate

- (void)boardReset
{
    currentScore = 0;
    [scoreLabel setText:@"0"];
    [cpuScoreLabel setText:@"0"];
    [boardContainer.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGSize size = CGSizeMake(600, 600);
    [boardContainer setFrame:CGRectMake(0, 0, size.width, size.height)];
    [boardScroller setContentSize:size];
    NSArray *board = [scrabble board];
    NSUInteger dimensions = [scrabble boardSize];
    NSInteger width = round(size.width / dimensions);
    NSInteger height = round(size.height / dimensions);
    for (NSInteger y = 0; y < dimensions; y++) {
        for (NSInteger x = 0; x < dimensions; x++) {
            CGRect frame = CGRectMake(x * width, y * height, width, height);
            SquareType type = [board[y][x] integerValue];
            CNScrabbleSquare *square = [[CNScrabbleSquare alloc] initWithFrame:frame type:type coord:CGPointMake(x + 1, y + 1)];
            [boardContainer addSubview:square];
        }
    }
    [boardContainer addSubview:latticeImage];
    [boardScroller setZoomScale:0.5f];
}

- (void)drewTile:(CNScrabbleTile *)tile
{
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panTile:)];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressTile:)];
    [pan setDelegate:self];
    [longPress setDelegate:self];
    [longPress setMinimumPressDuration:0.1f];
    [tile setGestureRecognizers:@[pan, longPress]];
}

- (void)drewTiles
{
    NSInteger count = [[scrabble drawnTiles] count];
    if (count == 0) return;
    CGFloat xpadding = 3;
    CGFloat tileWidth = 40;
    CGFloat totalWidth = tileWidth * count;
    CGFloat padding = xpadding * count;
    CGFloat xoffset = (320 - totalWidth - padding) / 2;
    for (NSInteger i = 0; i < count; i++) {
        CNScrabbleTile *tile = [scrabble drawnTiles][i];
        CGFloat x = round(xoffset + i * (tileWidth + xpadding));
        tile.frame = CGRectMake(x, 5, tileWidth, tileWidth);
        [tileRack addSubview:tile];
    }
    if ([[scrabble droppedTiles] count] == 0) {
        [scrabble determinePossibleWordsWithLetters:[scrabble lettersForTiles:scrabble.drawnTiles]];
    }
}

- (void)tilesReset
{
    [self removeHighlights];
}

- (void)highlightTiles:(NSArray *)tiles
{
    CGRect rect = [scrabble rectForTiles:tiles];
    UIView *view = [[UIView alloc] initWithFrame:rect];
    [view setBackgroundColor:[UIColor clearColor]];
    [view setTag:101];
    [view.layer setCornerRadius:3.f];
    [view.layer setBorderColor:[UIColor tileHighlight].CGColor];
    [view.layer setBorderWidth:3.f];
    [boardContainer addSubview:view];
}

- (void)removeHighlights
{
    for (UIView *v in boardContainer.subviews) {
        if (v.tag == 101) {
            [v removeFromSuperview];
        }
    }
}

#pragma mark - Search

- (void)keyboardDidHide:(NSNotification *)notification duration:(double)duration options:(UIViewAnimationOptions)options
{
    // HACK: Fix iOS7 content offsets
    self.searchDisplayController.searchResultsTableView.contentInset = UIEdgeInsetsZero;
    self.searchDisplayController.searchResultsTableView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchResults = nil;
    [self.searchDisplayController.searchResultsTableView reloadData];
}

- (void)doSearchWithText:(NSString*)searchText
{
    searchResults = [scrabble.dictionary wordsComparableWith:[searchText uppercaseString]];
    [self.searchDisplayController.searchResultsTableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [GameViewController cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(doSearchWithText:) withObject:searchText afterDelay:0.5f];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [searchResults count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *def = searchResults[indexPath.row][DEF_KEY];
    CGSize constraint = CGSizeMake(300, CGFLOAT_MAX);
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Light" size:14.f]};
    CGSize size = [def boundingRectWithSize:constraint options: NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:nil].size;
    size = CGSizeMake(ceil(size.width), ceil(size.height));
    return 35 + size.height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:16.f];
        cell.detailTextLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:14.f];
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
    }
    cell.textLabel.text = [searchResults[indexPath.row][NAME_KEY] lowercaseString];
    cell.detailTextLabel.text = searchResults[indexPath.row][DEF_KEY];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

#pragma mark - Interaction

- (void)themeChanged:(NSNotification*)notification
{
    [self applyTheme];
}

- (void)infoPressed:(id)sender
{
    CGFloat alpha = 1.0f;
    if (tilesView.alpha == alpha) {
        [self animateView:tilesView alpha:0.0f completion:nil];
    } else {
        [tilesView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [tilesView setContentSize:tilesView.bounds.size];
        static NSUInteger perRow = 6;
        NSUInteger rowCount = 0, colCount = 0;
        for (char c = 'A'; c <= 'Z'; c++) {
            NSString *letter = [NSString stringWithFormat:@"%c", c];
            NSUInteger count = 0;
            for (NSString *tile in scrabble.bagTiles) {
                if ([tile isEqualToString:letter]) {
                    count++;
                }
            }
            if (count > 0) {
                CNScrabbleTile *tile = [[CNScrabbleTile alloc] initWithFrame:CGRectMake(10 + (rowCount * (300 / perRow)), 10 + (50 * colCount), 40, 40) letter:letter];
                rowCount++;
                if (rowCount >= perRow) {
                    rowCount = 0;
                    colCount++;
                }
                tile.pointLabel.text = [NSString stringWithFormat:@"%d", count];
                [tilesView addSubview:tile];
                tile.pointLabel.textColor = [UIColor tileCountColor];
                tile.pointLabel.backgroundColor = [UIColor tileCountBackgroundColor];
                CGRect r = tile.pointLabel.frame;
                r.origin.y = 0;
                r.size.width = 14;
                r.size.height = 14;
                r.origin.x = 40 - r.size.width;
                tile.pointLabel.layer.borderColor = [UIColor tileBorderColor].CGColor;
                tile.pointLabel.layer.borderWidth = 1.f;
                tile.pointLabel.frame = r;
                tile.pointLabel.textAlignment = NSTextAlignmentCenter;
            }
        }
        if (rowCount > 0) {
            colCount++;
        }
        NSDictionary *lightAttributes = @{NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Light" size:16.f]};
        NSDictionary *boldAttributes = @{NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16.f]};
        NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@"Tiles remaining in bag: " attributes:lightAttributes]];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d\n\n", scrabble.bagTiles.count] attributes:boldAttributes]];
        
        for (NSDictionary *history in scrabble.playedHistory) {
            NSString *words = [history[HISTORY_WORDS_KEY] componentsJoinedByString:@", "];
            NSUInteger score = [history[HISTORY_SCORE_KEY] unsignedIntegerValue];
            [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[words stringByAppendingString:@" - "] attributes:lightAttributes]];
            [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d\n", score] attributes:boldAttributes]];
        }
        
        CGRect paragraphRect = [attr boundingRectWithSize:CGSizeMake(300, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:nil];
        paragraphRect.origin = CGPointMake(10, 10 + (50 *colCount));
        paragraphRect.size.height = ceil(paragraphRect.size.height);
        paragraphRect.size.width = ceil(paragraphRect.size.width);
        UILabel *label = [[UILabel alloc] initWithFrame:paragraphRect];
        [label setNumberOfLines:0];
        [label setLineBreakMode:NSLineBreakByWordWrapping];
        [label setAttributedText:attr];
        [tilesView addSubview:label];
        [tilesView.superview bringSubviewToFront:tilesView];
        CGRect r = [tilesView convertRect:label.frame toView:tilesView.superview];
        [tilesView setContentSize:CGSizeMake(320, r.origin.y + r.size.height + 44)];
        
        [self animateView:tilesView alpha:alpha completion:^{
            [self animateView:settingsView alpha:0.0f completion:nil];
        }];
    }
}

- (void)searchPressed:(id)sender
{
    [UIView animateWithDuration:0.35f animations:^{
        [tilesView setAlpha:0.0f];
        [settingsView setAlpha:0.0f];
    } completion:^(BOOL finished) {
        [self.searchDisplayController setActive:YES animated:YES];
        [self.searchDisplayController.searchBar becomeFirstResponder];
    }];
}

- (void)shufflePressed:(id)sender
{
    NSMutableArray *a = [NSMutableArray arrayWithArray:[scrabble drawnTiles]];
    NSMutableArray *b = [NSMutableArray array];
    CGFloat count = a.count;
    while (b.count != count) {
        NSInteger r = arc4random() % a.count;
        [b addObject:a[r]];
        [a removeObjectAtIndex:r];
    }
    [scrabble setDrawnTiles:b];
    [sender setEnabled:NO];
    [UIView animateWithDuration:0.35f animations:^{
        [self drewTiles];
    } completion:^(BOOL finished) {
        [sender setEnabled:YES];
    }];
}

- (void)playPressed:(id)sender
{
    [scrabble verifyValidityWithCompletion:^(NSInteger score, ValidityOptions status, NSString *message, NSArray *wordTilesArray) {
        if (status == VO_VALID) {
            [self removeHighlights];
            NSMutableArray *words = [NSMutableArray array];
            for (NSArray *wordTiles in wordTilesArray) {
                NSMutableString *word = [NSMutableString string];
                for (CNScrabbleTile *tile in wordTiles) {
                    [word appendString:tile.letterLabel.text];
                }
                [words addObject:word];
                [self highlightTiles:wordTiles];
            }
            currentScore += score;
            scoreLabel.text = [NSString stringWithFormat:@"%d", currentScore];
            [scrabble submitWords:words score:score];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Invalid" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
    }];
}

- (void)animateView:(UIView*)view alpha:(CGFloat)alpha completion:(void(^)(void))completion
{
    if (view.alpha == alpha) {
        if (completion) completion();
    } else {
        [UIView animateWithDuration:0.25f animations:^{
            view.alpha = alpha;
        } completion:^(BOOL finished) {
            if (completion) completion();
        }];
    }
}

- (void)settingsPressed:(id)sender
{
    // TODO: Prompt if user wants to commit these changes and lose their current game
    static NSInteger oldGameType = -1;
    static NSInteger oldTileCount = -1;
    NSInteger newGameType = [[SettingsDataSource sharedInstance] gameTypeIndex];
    NSInteger newTileCount = [[SettingsDataSource sharedInstance] countIndex];
    CGFloat alpha = 1.0f;
    if (settingsView.alpha == alpha) {
        if (oldGameType != newGameType || oldTileCount != newTileCount) {
            oldTileCount = newTileCount;
            oldGameType = newGameType;
            [scrabble resetGame];
        }
        [self animateView:settingsView alpha:0.0f completion:nil];
    } else {
        [settingsView.superview bringSubviewToFront:settingsView];
        oldGameType = newGameType;
        oldTileCount = newTileCount;
        [self animateView:settingsView alpha:alpha completion:^{
            [self animateView:tilesView alpha:0.0f completion:nil];
        }];
    }
}

- (void)zoomBoardAtPoint:(CGPoint)pt
{
    if (CGRectContainsPoint(boardScroller.frame, pt)) {
        CGPoint bpt = [boardContainer convertPoint:pt fromView:self.view];
        if (boardScroller.zoomScale < 1.0f) {
            // Zoom in on area user is hovering over
            CGRect brect = CGRectMake(bpt.x - boardScroller.frame.size.width*.5,
                                      bpt.y - boardScroller.frame.size.height*.5,
                                      boardScroller.frame.size.width, boardScroller.frame.size.height);
            [boardScroller zoomToRect:brect animated:YES];
        }
    }
    
}

- (void)moveBoard
{
    return;
    /*
     CGPoint pt = [self.view convertPoint:draggedTile.center fromView:draggedTile.superview];
     if (CGRectContainsPoint(boardScroller.frame, pt)) {
     CGPoint bpt = [boardContainer convertPoint:draggedTile.center fromView:draggedTile.superview];
     if (boardScroller.zoomScale == 1.0f) {
     CardinalDirections direction = [boardScroller getDirectionForEdgeWithPoint:bpt];
     if (direction != D_NONE) {*/
    // Wait in hover zone for 1s before scrolling
    // Should queue a selector and cancel if user moves outside of this zone
    /*static NSTimeInterval hover = 0;
     static CGFloat delay = 0.5f;
     NSTimeInterval currTime = [[NSDate date] timeIntervalSince1970];
     if (hover == 0.0f) {
     hover = currTime;
     return;
     }
     if (currTime - hover > delay) {
     hover = currTime;
     } else {
     return;
     }*/
    // Amount to add to current point
    /*             CGPoint toAdd = [boardScroller getOffsetForDirection:direction];
     CGPoint newPoint = CGPointMake(toAdd.x + bpt.x, toAdd.y + bpt.y);
     // Scroll to new point
     CGRect brect = CGRectMake(newPoint.x - boardScroller.frame.size.width*.5,
     newPoint.y - boardScroller.frame.size.height*.5,
     boardScroller.frame.size.width, boardScroller.frame.size.height);
     [boardScroller zoomToRect:brect animated:YES];
     }
     }
     }*/
}

- (void)selectLetter:(UITapGestureRecognizer*)tap
{
    if (pendingTile) {
        CNScrabbleTile *tile = (CNScrabbleTile*)[tap view];
        pendingTile.letterLabel.text = [[tile letterLabel] text];
        [self restoreNavigation:YES];
        [UIView animateWithDuration:0.35f animations:^{
            selectTileView.alpha = 0.0f;
            selectTileBackground.alpha = 0.0f;
        } completion:^(BOOL finished) {
            pendingTile = nil;
        }];
    }
}

- (void)doubleTapBoard:(UITapGestureRecognizer*)gesture
{
    if (boardScroller.zoomScale == 1.0f) {
        [boardScroller setZoomScale:0.5f animated:YES];
    } else {
        CGPoint pt = [gesture locationInView:boardContainer];
        CGRect brect = CGRectMake(pt.x - boardScroller.frame.size.width*.5,
                                  pt.y - boardScroller.frame.size.height*.5,
                                  boardScroller.frame.size.width, boardScroller.frame.size.height);
        [boardScroller zoomToRect:brect animated:YES];
    }
}

- (void)panTile:(UIPanGestureRecognizer*)gesture
{
    CNScrabbleTile *t = scrabble.draggedTile;
    if (t == gesture.view) {
        [self adjustAnchorPointForGestureRecognizer:gesture];
        // Adjust icon location
        CGPoint translation = [gesture translationInView:[t superview]];
        [t setCenter:CGPointMake([t center].x + translation.x, [t center].y + translation.y)];
        [gesture setTranslation:CGPointZero inView:[t superview]];
    }
}

- (void)longPressTile:(UILongPressGestureRecognizer*)gesture
{
    CNScrabbleTile *t = scrabble.draggedTile;
    if (t && t != gesture.view) return;
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            NSLog(@"Long Press Tile");
            t = (CNScrabbleTile*)gesture.view;
            scrabble.draggedTile = t;
            [boardScroller setUserInteractionEnabled:NO];
            [t.superview bringSubviewToFront:t];
            break;
        }
        case UIGestureRecognizerStateCancelled: {
            [boardScroller setUserInteractionEnabled:YES];
            [self drewTiles];
            scrabble.draggedTile = nil;
            break;
        }
        case UIGestureRecognizerStateEnded: {
            // TODO: Vibrate on drop on board/rack - setting
            // TODO: Restore to tile rack if user drags out of confines of board
            // TODO: Check that location is within visible area if zoomed in
            [boardScroller setUserInteractionEnabled:YES];
            
            CGPoint pt = [self.view convertPoint:t.center fromView:t.superview];
            CGPoint bpt = [gesture locationInView:boardContainer];  //[boardContainer convertPoint:t.center fromView:t.superview];
            CGRect visibleRect = [boardScroller convertRect:boardScroller.bounds toView:boardContainer];
            BOOL filled = NO;
            BOOL inbounds = CGRectContainsPoint(visibleRect, bpt);
            if (CGRectContainsPoint(boardScroller.frame, pt) && inbounds) {
                filled = ![scrabble isEmptyAtPoint:bpt];
            }
            if (!filled) {
                // Square is empty, add dragged tile
                filled = YES;
                if (inbounds) {
                    for (CNScrabbleSquare *square in boardContainer.subviews) {
                        if ([square isKindOfClass:[CNScrabbleSquare class]]) {
                            if (CGRectContainsPoint(square.frame, bpt)) {
                                if ([scrabble getTileAtX:square.coord.x y:square.coord.y]) {
                                    break;
                                }
                                [t setFrame:square.frame];
                                [t setCoord:square.coord];
                                [boardContainer addSubview:t];
                                [[scrabble drawnTiles] removeObject:t];
                                [[scrabble droppedTiles] addObject:t];
                                if ([[[t letterLabel] text] isEqualToString:@"?"]) {
                                    // Present Selector
                                    [self.navigationItem setRightBarButtonItems:nil animated:YES];
                                    [self.navigationItem setLeftBarButtonItems:nil animated:YES];
                                    [self.navigationItem setTitle:@"Select Letter"];
                                    pendingTile = t;
                                    selectTileView.backgroundColor = [UIColor tileRackColor];
                                    selectTileView.layer.shadowRadius = 2.f;
                                    selectTileView.layer.shadowOffset = CGSizeMake(1, 1);
                                    selectTileView.layer.shadowOpacity = 0.7f;
                                    selectTileView.layer.cornerRadius = 5.f;
                                    [selectTileBackground.superview bringSubviewToFront:selectTileBackground];
                                    [selectTileView.superview bringSubviewToFront:selectTileView];
                                    [UIView animateWithDuration:0.35f animations:^{
                                        selectTileView.alpha = 1.0f;
                                        selectTileBackground.alpha = 0.5f;
                                    } completion:^(BOOL finished) {
                                        
                                    }];
                                }
                                // Vibrate on drop?
                                //AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                                filled = NO;
                                break;
                            }
                        }
                    }
                }
            }
            if (filled) {
                // Square is filled, remove dragged tile
                if (![[scrabble drawnTiles] containsObject:t]) {
                    [[scrabble drawnTiles] addObject:t];
                }
                [[scrabble droppedTiles] removeObject:t];
            }
            // Show running score?
            //scoreLabel.text = [NSString stringWithFormat:@"%d", [scrabble calculateScore]];
            scrabble.draggedTile = nil;
            [self drewTiles];
            break;
        }
        default:
            break;
    }
}

- (void)adjustAnchorPointForGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        UIView *piece = gestureRecognizer.view;
        CGPoint locationInView = [gestureRecognizer locationInView:piece];
        CGPoint locationInSuperview = [gestureRecognizer locationInView:piece.superview];
        piece.layer.anchorPoint = CGPointMake(locationInView.x / piece.bounds.size.width, locationInView.y / piece.bounds.size.height);
        piece.center = locationInSuperview;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] &&
         [otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) ||
        ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]] &&
         [otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]))
    {
        return YES;
    }
    return NO;
}


@end
