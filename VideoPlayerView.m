//
//  VideoPlayerView.m
//  SH
//
//  Created by Jonas Jongejan on 07/01/13.
//  Copyright (c) 2013 HalfdanJ. All rights reserved.
//

#import "VideoPlayerView.h"
#import "NSString+Timecode.h"

@interface VideoPlayerView ()

@property NSSlider * timeSlider;
@property NSButton * playButton;
@property NSTextField * timeTextField;

@property AVPlayer * avPlayer;
@property AVPlayerLayer * avPlayerLayer;

@property id timeObserverToken;
@property id timeOutObserverToken;
@end


#pragma mark - Implementation


@implementation VideoPlayerView

static void *MovieItemContext = &MovieItemContext;
static void *AVSPPlayerLayerReadyForDisplay = &AVSPPlayerLayerReadyForDisplay;

static void *InTimeContext = &InTimeContext;
static void *OutTimeContext = &OutTimeContext;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setWantsLayer:YES];
        
        //Background layer
        CALayer * background = [CALayer layer];
        background.backgroundColor = [[NSColor blackColor] CGColor];
        
        CGRect frame = NSRectToCGRect(self.bounds);
        frame.size.height -= 20;
        frame.origin.y += 20;
        
        background.frame = frame;
        
        [self.layer addSublayer:background];
        

        
        
        //Slider
        self.timeSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(40, 0, self.frame.size.width-80, 20)];
        [self.timeSlider bind:@"value" toObject:self withKeyPath:@"currentTime" options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
        [self.timeSlider bind:@"maxValue" toObject:self withKeyPath:@"duration" options:nil];
        [self.timeSlider setEnabled:NO];

        [self addSubview:self.timeSlider];
        
        
        //Time view
        self.timeTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(self.frame.size.width-40, 0, 40, 20)];
        [self.timeTextField setEditable:NO];
        self.timeTextField.drawsBackground = NO;
        [self.timeTextField setBordered:NO];
        [self.timeTextField setBezeled:NO];
        
        [self addSubview:self.timeTextField];
        
        
        //Play button
        self.playButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 20)];
        [self.playButton setButtonType:NSPushOnPushOffButton];
        [self.playButton setBezelStyle:NSRoundRectBezelStyle];
        [self.playButton setImagePosition:   NSImageOnly  ];
        [self.playButton setImage:[NSImage imageNamed:@"NSRightFacingTriangleTemplate"]];
        [self.playButton bind:@"value" toObject:self withKeyPath:@"playing" options:nil];
        [self.playButton setEnabled:NO];

        
        [self addSubview:self.playButton];
        
        [self addObserver:self forKeyPath:@"movieItem" options:0 context:MovieItemContext];
        [self addObserver:self forKeyPath:@"inTime" options:0 context:InTimeContext];
        [self addObserver:self forKeyPath:@"outTime" options:0 context:OutTimeContext];

    }
    
    return self;
}



-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    
    if(context == InTimeContext){
        [self.avPlayer seekToTime:CMTimeMakeWithSeconds([self.inTime doubleValue], 100) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }
    if(context == OutTimeContext){
        if(self.timeOutObserverToken){
            [self.avPlayer removeTimeObserver:self.timeOutObserverToken];
        }
        self.timeOutObserverToken = [self.avPlayer addBoundaryTimeObserverForTimes:@[[NSValue valueWithCMTime:CMTimeMakeWithSeconds([self.outTime doubleValue], 100)]]  queue:dispatch_get_current_queue() usingBlock:^{
            [self.avPlayer pause];
        }];
    }
    
    if (context == AVSPPlayerLayerReadyForDisplay)
	{
		if ([[change objectForKey:NSKeyValueChangeNewKey] boolValue] == YES)
		{
			// The AVPlayerLayer is ready for display. 
			[self.avPlayerLayer setHidden:NO];
            [self.playButton setEnabled:YES];
            [self.timeSlider setEnabled:YES];
		}
	}
    
    if(context == MovieItemContext){
        NSLog(@"Changed movie item %@" , self.movieItem);
        
        [self.playButton setEnabled:NO];
        [self.timeSlider setEnabled:NO];
        self.timeTextField.stringValue = [NSString stringWithTimecode:0];
        
        [self.avPlayer removeTimeObserver:self.timeObserverToken];
        self.timeObserverToken = nil;
        
        if(self.timeOutObserverToken){
            [self.avPlayer removeTimeObserver:self.timeOutObserverToken];
            self.timeOutObserverToken = nil;
        }
        
        if(self.avPlayerLayer){
            [self.avPlayerLayer removeFromSuperlayer];
        }
        
        AVAsset * asset = self.movieItem.asset;
        
        if (![asset isPlayable] || [asset hasProtectedContent])
        {
            // We can't play this asset. Show the "Unplayable Asset" label.
         //   [self stopLoadingAnimationAndHandleError:nil];
           // [[self unplayableLabel] setHidden:NO];
            

            NSLog(@"Not able to play asset");
            return;
        }
        
        // Create a new AVPlayerItem and make it our player's current item.
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];

        
        //[self.avPlayer replaceCurrentItemWithPlayerItem:playerItem];
        self.avPlayer = [AVPlayer playerWithPlayerItem:playerItem];
        if(self.inTime){
            [self.avPlayer seekToTime:CMTimeMakeWithSeconds([self.inTime doubleValue], 100)];
            self.timeTextField.stringValue = [NSString stringWithTimecode:[self.inTime doubleValue]];

        }
        
        if(self.outTime){
            NSLog(@"Out time %@",self.outTime);
            self.timeOutObserverToken = [self.avPlayer addBoundaryTimeObserverForTimes:@[[NSValue valueWithCMTime:CMTimeMakeWithSeconds([self.outTime doubleValue], 100)]]  queue:dispatch_get_current_queue() usingBlock:^{
                [self.avPlayer pause];
            }];
        }
        
        self.timeObserverToken = [self.avPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {

            [self.timeSlider setDoubleValue:CMTimeGetSeconds(time)];
            self.timeTextField.stringValue = [NSString stringWithTimecode:CMTimeGetSeconds(time)];

        }];
        
        
        
        // Create an AVPlayerLayer and add it to the player view if there is video, but hide it until it's ready for display
        CGRect frame = NSRectToCGRect(self.bounds);
        frame.size.height -= 20;
        frame.origin.y += 20;
        
        AVPlayerLayer *newPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.avPlayer];
        [newPlayerLayer setFrame:frame];
        newPlayerLayer.videoGravity = AVLayerVideoGravityResize;
        [newPlayerLayer setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
         [newPlayerLayer setHidden:YES];
        [self.layer addSublayer:newPlayerLayer];
        
        
        self.avPlayerLayer = newPlayerLayer;
        [self addObserver:self forKeyPath:@"avPlayerLayer.readyForDisplay" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:AVSPPlayerLayerReadyForDisplay];

    }
}


#pragma mark - Getters / Setters


- (double)duration
{
	AVPlayerItem *playerItem = [self.avPlayer currentItem];
	
	if ([playerItem status] == AVPlayerItemStatusReadyToPlay)
		return CMTimeGetSeconds([[playerItem asset] duration]);
	else
		return 0.f;
}

+ (NSSet *)keyPathsForValuesAffectingDuration
{
	return [NSSet setWithObjects:@"avPlayer.currentItem", @"avPlayer.currentItem.status", nil];
}



- (double)currentTime
{
	return CMTimeGetSeconds([self.avPlayer currentTime]);
}

- (void)setCurrentTime:(double)time
{
	[self.avPlayer seekToTime:CMTimeMakeWithSeconds(time, 100) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}



-(BOOL) playing {
    return self.avPlayer.rate;
}

-(void) setPlaying:(BOOL)playing{
    if(playing){
        if(self.inTime){
            if(CMTimeGetSeconds(self.avPlayer.currentTime ) < [self.inTime doubleValue]){
                [self.avPlayer seekToTime:CMTimeMakeWithSeconds([self.inTime doubleValue], 100) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
            }
            
        }
        [self.avPlayer play];
    } else {
        [self.avPlayer pause];
    }
}

+(NSSet *)keyPathsForValuesAffectingPlaying{
    return [NSSet setWithObject:@"avPlayer.rate"];
}
@end
