//
//  WindowAdditions.mm
//  TintedMac
//
//  Created on 2024.
//  Copyright © 2024 TintedMac. All rights reserved.
//

#import "WindowAdditions.h"
#import <QuartzCore/QuartzCore.h>

@implementation NSWindow (TintedMacAdditions)

- (void)applyTintEffect {
    // Apply a subtle tint overlay to the window
    CALayer *tintLayer = [CALayer layer];
    tintLayer.backgroundColor = [[NSColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.1] CGColor];
    tintLayer.frame = self.contentView.bounds;
    tintLayer.name = @"TintedMacOverlay";
    
    [self.contentView.layer addSublayer:tintLayer];
    [self.contentView setWantsLayer:YES];
}

- (void)removeTintEffect {
    // Remove the tint overlay
    NSArray *sublayers = [self.contentView.layer.sublayers copy];
    for (CALayer *layer in sublayers) {
        if ([layer.name isEqualToString:@"TintedMacOverlay"]) {
            [layer removeFromSuperlayer];
        }
    }
}

- (void)updateTintColor:(NSColor *)color {
    // Update the tint color
    NSArray *sublayers = [self.contentView.layer.sublayers copy];
    for (CALayer *layer in sublayers) {
        if ([layer.name isEqualToString:@"TintedMacOverlay"]) {
            layer.backgroundColor = [color CGColor];
        }
    }
}

@end