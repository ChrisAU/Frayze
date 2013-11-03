//
//  FirstViewController.m
//  WordPlay
//
//  Created by CJNevin on 30/10/2013.
//  Copyright (c) 2013 CJNevin. All rights reserved.
//

#import "GameViewController.h"
#import "UIScrollView+Directions.h"
#import "NSArray+NumberComparison.h"
#import <AudioToolbox/AudioServices.h>

@interface GameViewController ()
{
    NSUInteger currentScore;
    UIView *boardContainer;
    UIScrollView *boardScroller;
    UILabel *scoreLabel;
    
    CNScrabble *scrabble;
}
@end

@implementation GameViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    CGFloat topOffset = 30 + 44, leftOffset = 10;
    boardScroller = [[UIScrollView alloc] initWithFrame:CGRectMake(leftOffset, topOffset, 300, 300)];
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
    [boardScroller.layer setBorderColor:[UIColor squareBorderColor].CGColor];
    [self.view insertSubview:boardScroller belowSubview:settingsView];
    [self.view setBackgroundColor:[UIColor gameBackgroundColor]];
    
    scoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftOffset, topOffset + 300 + 10, 300, 25)];
    [self.view addSubview:scoreLabel];
    
    UIBarButtonItem *play = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(playPressed:)];
    UIBarButtonItem *settings = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(settingsPressed:)];
    [self.navigationItem setLeftBarButtonItems:@[settings]];
    [self.navigationItem setRightBarButtonItems:@[play]];
    [self.navigationItem setTitle:@"Frayze"];
    
    tileRack.backgroundColor = [UIColor tileRackColor];

    // Finally setup the scrabble board
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
    return boardContainer;
}

#pragma mark - Delegate

- (void)boardReset
{
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
    [boardScroller setZoomScale:0.5f];
}

- (void)drewTile:(CNScrabbleTile *)tile
{
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panTile:)];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressTile:)];
    [pan setDelegate:self];
    [longPress setDelegate:self];
    [longPress setMinimumPressDuration:0.25f];
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
        tile.frame = CGRectMake(x, 10, tileWidth, tileWidth);
        [tileRack addSubview:tile];
    }
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

#pragma mark - Gestures

- (void)playPressed:(id)sender
{
    if (![scrabble canSubmit]) {
        [[[UIAlertView alloc] initWithTitle:@"Invalid Placement" message:@"Please place tiles horizontally/vertically." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    } else {
        [self removeHighlights];
        currentScore += [scrabble calculateScore:NO];
        scoreLabel.text = [NSString stringWithFormat:@"%d", currentScore];
        [scrabble submit];
    }
}

- (void)settingsPressed:(id)sender
{
    [UIView animateWithDuration:0.5f animations:^{
        if (settingsView.alpha == 0.8f) {
            settingsView.alpha = 0.0f;
        } else {
            settingsView.alpha = 0.8f;
        }
    }];
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
            [boardScroller setUserInteractionEnabled:YES];
            
            CGPoint pt = [self.view convertPoint:t.center fromView:t.superview];
            CGPoint bpt = [gesture locationInView:boardContainer];
            //CGPoint bpt = [boardContainer convertPoint:[gesture locationInView:t] fromView:t.superview];
            BOOL filled = NO;
            if (CGRectContainsPoint(boardScroller.frame, pt)) {
                filled = ![scrabble isEmptyAtPoint:bpt];
            }
            if (!filled) {
                // Square is empty, add dragged tile
                filled = YES;
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
                            // Vibrate on drop
                            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                            filled = NO;
                            break;
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

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

@end