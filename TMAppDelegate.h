//
//  TMAppDelegate.h
//  Debordelizer
//
//  Created by Matej Sychra on 02/11/2009.
//

#import <Cocoa/Cocoa.h>

@interface TMAppDelegate : NSObject <NSWindowDelegate>
{
    NSWindow *window;
	BOOL showsHelpWhenActive;
	NSWindow *helpWindow;
	NSMenu *statusMenu;
	NSStatusItem *statusItem;
	NSPanel *prefsWindow;
	NSButton *dockIconCheckbox;
	NSMenuItem *stateMenuItemMainMenu;
    NSMenuItem *externalMenuItemMainMenu;
	NSMenuItem *stateMenuItemStatusBar;
    NSMenuItem *externalMenuItemStatusBar;
	BOOL shouldHideClutter;
    BOOL externalEnabled;
    float opacity;
}

@property (assign) IBOutlet NSWindow *window;
@property (nonatomic, assign) float opacity;
@property (assign) IBOutlet NSMenu *statusMenu;
@property (assign) IBOutlet NSPanel *prefsWindow;
@property (assign) IBOutlet NSButton *dockIconCheckbox;
@property (assign) IBOutlet NSMenuItem *stateMenuItemMainMenu;
@property (assign) IBOutlet NSMenuItem *externalMenuItemMainMenu;
@property (assign) IBOutlet NSMenuItem *stateMenuItemStatusBar;
@property (assign) IBOutlet NSMenuItem *externalMenuItemStatusBar;

- (IBAction)showAbout:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)toggleDockIcon:(id)sender;
- (IBAction)toggleEnabledStatus:(id)sender;
- (IBAction)toggleExternalStatus:(id)sender;

- (void)applicationActiveStateChanged:(NSNotification *)aNotification;
- (void)toggleHelpDisplay;
- (void)updateEnabledStatus;
- (void)updateExternalStatus;

- (void)keyDown:(NSEvent *)event;

@end
