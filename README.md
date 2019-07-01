# LOKIE

A framework for building iOS AOP.

Support iOS 8.0+ 



## building Lokie 

* open Lokie.xcodeproj with Xcode and build it
* defualt configuration will build Lokie.framework for you
* you can use Lokie.framework as other normal framework in your project
* Enjoy it.

## Use Lokie

### API  

```
//! Lokie.h
#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    LokieHookPolicyBefore = 1 << 0,
    LokieHookPolicyAfter = 1 << 1,
    LokieHookPolicyReplace = 1 << 2,
    LokieHookPolicyPatchEnv = 1 << 3,
} LokieHookPolicy;

@interface NSObject (Lokie)

+ (BOOL) Lokie_hookMemberSelector:(NSString *) selecctor_name
                        withBlock: (id) block
                           policy:(LokieHookPolicy) policy;

+ (BOOL) Lokie_hookClassSelector:(NSString *) selecctor_name
                       withBlock: (id) block
                          policy:(LokieHookPolicy) policy;

+ (BOOL) Lokie_resetSelector:(NSString *) selector_name withType:(BOOL) isMember;

+ (NSArray *) LokieErrorStack;

@end

```

### How to use

```
#include <Lokie/Lokie.h>

//! insert something before UIViewController::viewDidAppear:
Class cls = NSClassFromString(@"UIViewController");
[cls Lokie_hookMemberSelector:@"viewDidAppear:" withBlock:^(id target, BOOL ani){
        NSLog(@"LOKIE: before viewDidAppear");
 }policy:LokieHookPolicyBefore];

[cls Lokie_hookMemberSelector:@"viewDidAppear:" withBlock:^(id target, BOOL ani){
         NSLog(@"LOKIE: after viewDidAppear");
 }policy:LokieHookPolicyAfter];
 
//! we can insert some code before/after 
Class cls = NSClassFromString(@"MyViewController");
[cls Lokie_hookMemberSelector:@"initWithConfig:"
                    withBlock:^(id target, NSDictionary *param){
                        NSLog(@"%@", param);
                        NSLog(@"Lokie: %@ is created", target);
} policy:LokieHookPolicyAfter];
    
//! hooked selector does not has any param
[cls Lokie_hookMemberSelector:@"dealloc" withBlock:^(id target){
        NSLog(@"Lokie: %@ is dealloc", target);
} policy:LokieHookPolicyBefore];

```