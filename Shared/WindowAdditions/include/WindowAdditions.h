//
//  WindowAdditions.h
//  TintedMac
//
//  Created on 2024.
//  Copyright © 2024 TintedMac. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSWindow (TintedMacAdditions)

- (void)applyTintEffect;
- (void)removeTintEffect;
- (void)updateTintColor:(NSColor *)color;

@end