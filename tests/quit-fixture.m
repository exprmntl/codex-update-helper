#import <Cocoa/Cocoa.h>

@interface FixtureDelegate : NSObject <NSApplicationDelegate>
@property NSString *mode;
@end
@implementation FixtureDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    puts("fixture-ready");
    fflush(stdout);
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    (void)sender;
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Quit ChatGPT?";
    alert.informativeText = [self.mode isEqualToString:@"scheduled"]
        ? @"Scheduled tasks won't run while ChatGPT is closed"
        : @"Active local chats on this machine will be interrupted and scheduled tasks won't run while ChatGPT is closed";
    [alert addButtonWithTitle:@"Quit"];
    [alert addButtonWithTitle:@"Cancel"];
    return [alert runModal] == NSAlertFirstButtonReturn ? NSTerminateNow : NSTerminateCancel;
}
@end
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        FixtureDelegate *delegate = [FixtureDelegate new];
        delegate.mode = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"active";
        app.delegate = delegate;
        [app run];
    }
}
