//
//  TMAppDelegate.m
//  Debordelizer
//
//  Created by Matej Sychra on 02/11/2009.
//

#import "TMAppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import "MGTransparentWindow.h"
#import "NSApplication+DockIcon.h"

#define OPACITY_UNIT				1.0;
#define DEFAULT_OPACITY				0.0

#define STATE_MENU					NSLocalizedString(@"Turn Debordelizer Off", nil) // global status menu-item title when enabled
#define STATE_MENU_OFF				NSLocalizedString(@"Turn Debordelizer On", nil) // global status menu-item title when disabled

#define EXTERNAL_MENU					NSLocalizedString(@"Turn External Display Off", nil) // global status menu-item title when enabled
#define EXTERNAL_MENU_OFF				NSLocalizedString(@"Turn External Display On", nil) // global status menu-item title when disabled
#define EXTERNAL_MENU_NONE				NSLocalizedString(@"No External Display", nil) // global status menu-item title when no display connected

#define HELP_TEXT					NSLocalizedString(@"When Debordelizer is frontmost:\rPress Up/Down to alter shade,\ror press Q to Quit.", nil)
#define HELP_TEXT_OFF				NSLocalizedString(@"Debordelizer is Off.\rPress S to turn Debordelizer on,\ror press Q to Quit.", nil)

#define STATUS_MENU_ICON			[NSImage imageNamed:@"Shady_Menu_Dark"]
#define STATUS_MENU_ICON_ALT		[NSImage imageNamed:@"Shady_Menu_Light"]
#define STATUS_MENU_ICON_OFF		[NSImage imageNamed:@"Shady_Menu_Dark_Off"]
#define STATUS_MENU_ICON_OFF_ALT	[NSImage imageNamed:@"Shady_Menu_Light_Off"]

#define MAX_OPACITY					(0.95) // the darkest the screen can be, where 1.0 is pure black.
#define KEY_OPACITY					@"DbrdlzrSavedOpacityKey" // name of the saved opacity setting.
#define KEY_DOCKICON				@"DbrdlzrSavedDockIconKey" // name of the saved dock icon state setting.
#define KEY_ENABLED					@"DbrdlzrSavedEnabledKey" // name of the saved primary state setting.
#define KEY_EXTERNAL				@"DbrdlzrSavedExternalKey" // name of the saved secondary state setting.

@implementation TMAppDelegate

@synthesize window;
@synthesize opacity;
@synthesize statusMenu;
@synthesize prefsWindow;
@synthesize dockIconCheckbox;
@synthesize stateMenuItemMainMenu;
@synthesize stateMenuItemStatusBar;
@synthesize externalMenuItemMainMenu;
@synthesize externalMenuItemStatusBar;


#pragma mark Setup and Tear-down


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Set the default opacity value and load any saved settings.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
								[NSNumber numberWithBool:YES], KEY_DOCKICON, 
								[NSNumber numberWithBool:YES], KEY_ENABLED,
                                [NSNumber numberWithBool:YES], KEY_EXTERNAL,
								nil]];
	
	// Set up Dock icon.
	BOOL showsDockIcon = [defaults boolForKey:KEY_DOCKICON];
	[dockIconCheckbox setState:(showsDockIcon) ? NSOnState : NSOffState];
	if (showsDockIcon) {
		// Only set it here if it's YES, since we've just read a saved default and we always start with no Dock icon.
		[NSApp setShowsDockIcon:showsDockIcon];
	}
	
	// Create transparent window starting in bottom right screen corner.

    NSRect mainFrame = [[NSScreen mainScreen] frame];
	NSRect screensFrame = NSMakeRect(mainFrame.size.width, mainFrame.size.height, 1, 1);

    // Dim all but the main screen (hopefully it's not in the middle - a bug comes here!)
	for (NSScreen *thisScreen in [NSScreen screens]) {
        if (thisScreen != [NSScreen mainScreen]) {
            screensFrame = NSUnionRect(screensFrame, [thisScreen frame]);
        }
	}
	window = [[MGTransparentWindow windowWithFrame:screensFrame] retain];
	
	// Configure window.
	[window setReleasedWhenClosed:YES];
	[window setHidesOnDeactivate:NO];
	[window setCanHide:NO];
	[window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	[window setIgnoresMouseEvents:YES];
	[window setLevel:NSScreenSaverWindowLevel];
	[window setDelegate:self];
	
	// Configure contentView.
	NSView *contentView = [window contentView];
	[contentView setWantsLayer:YES];
	CALayer *layer = [contentView layer];
	layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
	layer.opacity = 0;
	[window makeFirstResponder:contentView];
	
	// Activate statusItem.
	NSStatusBar *bar = [NSStatusBar systemStatusBar];
    statusItem = [bar statusItemWithLength:NSSquareStatusItemLength];
    [statusItem retain];
    [statusItem setImage:STATUS_MENU_ICON];
	[statusItem setAlternateImage:STATUS_MENU_ICON_ALT];
    [statusItem setHighlightMode:YES];
    [statusItem setMenu:statusMenu];
	
	// Set appropriate initial display state.
	shouldHideClutter = [defaults boolForKey:KEY_ENABLED];
	[self updateEnabledStatus];

    // Set appropriate initial external display disable state.
    externalEnabled = [defaults boolForKey:KEY_EXTERNAL];
    [self updateExternalStatus];
	
	// Only show help text when activated _after_ we've launched and hidden ourselves.
	showsHelpWhenActive = NO;
	
	// Put this app into the background (the shade won't hide due to how its window is set up above).
	[NSApp hide:self];
	
	// Put window on screen.
	[window makeKeyAndOrderFront:self];
}


- (void)dealloc
{
	if (statusItem) {
		[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
		[statusItem release];
		statusItem = nil;
	}
	[window removeChildWindow:helpWindow];
	[helpWindow close];
	[window close];
	window = nil; // released when closed.
	helpWindow = nil; // released when closed.
	
	[super dealloc];
}


#pragma mark Notifications handlers


- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
	[self applicationActiveStateChanged:aNotification];
}


- (void)applicationDidResignActive:(NSNotification *)aNotification
{
	[self applicationActiveStateChanged:aNotification];
}


- (void)applicationActiveStateChanged:(NSNotification *)aNotification
{
	BOOL appActive = [NSApp isActive];
	if (appActive) {
		// Give the window a kick into focus, so we still get key-presses.
		[window makeKeyAndOrderFront:self];
	}
	
	if (!showsHelpWhenActive && !appActive) {
		// Enable help text display when active from now on.
		showsHelpWhenActive = YES;
		
	} else if (showsHelpWhenActive) {
		[self toggleHelpDisplay];
	}
}


#pragma mark IBActions


- (IBAction)showAbout:(id)sender
{
	// We wrap this for the statusItem to ensure Debordelizer comes to the front first.
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:self];
}


- (IBAction)showPreferences:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[prefsWindow makeKeyAndOrderFront:self];
}


- (IBAction)toggleDockIcon:(id)sender
{
	BOOL showsDockIcon = ([sender state] != NSOffState);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:showsDockIcon forKey:KEY_DOCKICON];
	[defaults synchronize];
	[NSApp setShowsDockIcon:showsDockIcon];
}


- (IBAction)toggleEnabledStatus:(id)sender
{
	shouldHideClutter = !shouldHideClutter;
	[self updateEnabledStatus];
}

- (IBAction)toggleExternalStatus:(id)sender
{
	externalEnabled = !externalEnabled;
	[self updateExternalStatus];
}


#pragma mark Helper methods


- (void)toggleHelpDisplay
{
	if (!helpWindow) {
		// Create helpWindow.
		NSRect mainFrame = [[NSScreen mainScreen] frame];
		NSRect helpFrame = NSZeroRect;
		float width = 600;
		float height = 200;
		helpFrame.origin.x = (mainFrame.size.width - width) / 2.0;
		helpFrame.origin.y = 200.0;
		helpFrame.size.width = width;
		helpFrame.size.height = height;
		helpWindow = [[MGTransparentWindow windowWithFrame:helpFrame] retain];
		
		// Configure window.
		[helpWindow setReleasedWhenClosed:YES];
		[helpWindow setHidesOnDeactivate:NO];
		[helpWindow setCanHide:NO];
		[helpWindow setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		[helpWindow setIgnoresMouseEvents:YES];
		
		// Configure contentView.
		NSView *contentView = [helpWindow contentView];
		[contentView setWantsLayer:YES];
		CATextLayer *layer = [CATextLayer layer];
		layer.opacity = 0;
		[contentView setLayer:layer];
		CGColorRef bgColor = CGColorCreateGenericGray(0.0, 0.6);
		layer.backgroundColor = bgColor;
		CGColorRelease(bgColor);
		layer.string = (shouldHideClutter) ? HELP_TEXT : HELP_TEXT_OFF;
		layer.contentsRect = CGRectMake(0, 0, 1, 1.2);
		layer.fontSize = 40.0;
		layer.foregroundColor = CGColorGetConstantColor(kCGColorWhite);
		layer.borderColor = CGColorGetConstantColor(kCGColorWhite);
		layer.borderWidth = 4.0;
		layer.cornerRadius = 15.0;
		layer.alignmentMode = kCAAlignmentCenter;
		
		[window addChildWindow:helpWindow ordered:NSWindowAbove];
	}

	if (showsHelpWhenActive) {
		//float helpOpacity = (([NSApp isActive] ? 1 : 0));
		//[[[helpWindow contentView] layer] setOpacity:helpOpacity];
	}
}

- (void)updateEnabledStatus
{
	// Save state.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:shouldHideClutter forKey:KEY_ENABLED];
	[defaults synchronize];
	
	// Show or hide the shade layer's view appropriately.
	[[[window contentView] animator] setHidden:!shouldHideClutter];
	
	// Modify help text shown when we're frontmost.
	if (helpWindow) {
		CATextLayer *helpLayer = (CATextLayer *)[[helpWindow contentView] layer];
		helpLayer.string = (shouldHideClutter) ? HELP_TEXT : HELP_TEXT_OFF;
	}
	
	// Update both enable/disable menu-items (in the main menubar and in the NSStatusItem's menu).
	[stateMenuItemMainMenu setTitle:(shouldHideClutter) ? STATE_MENU : STATE_MENU_OFF];
	[stateMenuItemStatusBar setTitle:(shouldHideClutter) ? STATE_MENU : STATE_MENU_OFF];
	
	// Update status item's regular and alt/selected images.
	[statusItem setImage:(shouldHideClutter) ? STATUS_MENU_ICON : STATUS_MENU_ICON_OFF];
	[statusItem setAlternateImage:(shouldHideClutter) ? STATUS_MENU_ICON_ALT : STATUS_MENU_ICON_OFF_ALT];

    [self toggleStatus];
}

- (void)keyDown:(NSEvent *)event
{
	if ([event window] == window) {
		unsigned short keyCode = [event keyCode];
		if (keyCode == 12 || keyCode == 53) { // q || Esc
			[NSApp terminate:self];

		} else if (keyCode == 126) { // up-arrow
			[self hidePresentation:self];

		} else if (keyCode == 125) { // down-arrow
			[self showPresentation:self];

		} else if (keyCode == 1) { // s
			[self toggleEnabledStatus:self];

		} else if (keyCode == 43) { // ,
			[self showPreferences:self];

		} else {
			//NSLog(@"keyCode: %d", keyCode);
		}
	}
}

- (IBAction)hidePresentation:(id)sender
{
	// i.e. make screen darker by making our mask less transparent.
	if (externalEnabled) {
		self.opacity = opacity + OPACITY_UNIT;
	} else {
		NSBeep();
	}
}


- (IBAction)showPresentation:(id)sender
{
	// i.e. make screen lighter by making our mask more transparent.
	if (!externalEnabled) {
		self.opacity = opacity - OPACITY_UNIT;
	} else {
		NSBeep();
	}
}

-(void)toggleStatus
{
    //
    // defaults write com.apple.finder CreateDesktop -bool true; killall Finder
    // defaults write com.apple.finder CreateDesktop -bool false; killall Finder
    //

    if (shouldHideClutter) {

        // hide desktop icons
        [NSTask launchedTaskWithLaunchPath:@"/usr/bin/defaults" arguments:
         [NSArray arrayWithObjects:@"write", @"com.apple.finder", @"CreateDesktop", @"-bool", @"false", nil]
         ];

        // restart finder
        [NSTask launchedTaskWithLaunchPath:@"/usr/bin/killall" arguments:
         [NSArray arrayWithObjects:@"Finder", nil]
         ];

    } else {

        // unhide desktop icons
        [NSTask launchedTaskWithLaunchPath:@"/usr/bin/defaults" arguments:
         [NSArray arrayWithObjects:@"write", @"com.apple.finder", @"CreateDesktop", @"-bool", @"true", nil]
         ];

        // restart finder
        [NSTask launchedTaskWithLaunchPath:@"/usr/bin/killall" arguments:
         [NSArray arrayWithObjects:@"Finder", nil]
         ];
    }
}

-(void)updateExternalStatus
{
    // Save state.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:externalEnabled forKey:KEY_EXTERNAL];
	[defaults synchronize];

    if ([[NSScreen screens] count] > 1) {
        // Update both enable/disable menu-items (in the main menubar and in the NSStatusItem's menu).
        [self.externalMenuItemMainMenu setTitle:(externalEnabled) ? EXTERNAL_MENU : EXTERNAL_MENU_OFF];
        [self.externalMenuItemStatusBar setTitle:(externalEnabled) ? EXTERNAL_MENU : EXTERNAL_MENU_OFF];
    } else {
        [self.externalMenuItemMainMenu setTitle:EXTERNAL_MENU_NONE];
        [self.externalMenuItemStatusBar setTitle:EXTERNAL_MENU_NONE];
    }

    // Show or hide the shade layer's view appropriately.
	[[[window contentView] animator] setHidden:!externalEnabled];

    if (!externalEnabled) {
        [self showPresentation:self];
    } else {
        [self hidePresentation:self];
    }
}

#pragma mark Accessors


- (void)setOpacity:(float)newOpacity
{
	float normalisedOpacity = MIN(MAX_OPACITY, MAX(newOpacity, 0.0));
	if (normalisedOpacity != opacity) {
		opacity = normalisedOpacity;
		[[[window contentView] layer] setOpacity:opacity];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setFloat:opacity forKey:KEY_OPACITY];
		[defaults synchronize];
	}
}

@end
