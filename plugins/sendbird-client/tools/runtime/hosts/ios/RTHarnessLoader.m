// Runtime harness (added to a copy of the app, never to the project): once the app has finished
// launching, call RTHarness.start (RTHarness.swift), which signs in through the app's own
// LoginService. Objective-C because Swift has no load-time hook; does nothing unless the
// harness launched the app with RT_USER_ID.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

__attribute__((constructor)) static void RTHarnessInstall(void) {
    if (NSProcessInfo.processInfo.environment[@"RT_USER_ID"] == nil) return;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        Class harness = NSClassFromString(@"RTHarness");
        SEL start = NSSelectorFromString(@"start");
        if (harness && [harness respondsToSelector:start]) {
            ((void (*)(id, SEL))objc_msgSend)(harness, start);
        }
    }];
}
