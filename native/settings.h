#import <Cocoa/Cocoa.h>
NSDictionary<NSString *, NSString *> *defaultSettings(void);
NSDictionary<NSString *, NSString *> *loadSettings(NSError **error);
int settingsCommand(int argc, const char *argv[]);
int showSettings(void);
