/* Copyright (c) 2019, 2020, 2021, 2022 Alibaba, Inc.
 
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 ``Software''), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED ``AS IS'', WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.  */

#import "Lokie.h"
#include "LokieMicro.h"
#include "LokieContainer.h"
#include "LokieHookAction.h"

BEGIN_DECLERE_C
LokieTSVector<NSString *> g_error_list;

void LokieSetError(NSString *err){
    g_error_list.insert(err);
}

NSArray *LokieErrorStack(){
    auto c = g_error_list.copy();
    size_t size = c.size();
    NSMutableArray *res = nil;
    if (size > 0){
        res = [[NSMutableArray alloc] initWithCapacity:c.size()];
        for( NSString *item :  c){ [res addObject: item]; }
    }
    g_error_list.clear();
    return res;
}

extern BOOL lk_hook(id self, Lokie_hook_func_type ftype,
                    SEL sel, id block, LokieHookPolicy policy);

extern BOOL lk_unhook(id self, SEL sel, BOOL ismember);
END_DECLERE_C

@implementation NSObject (Lokie)

+(BOOL) Lokie_hookMemberSelector:(NSString *) selecctor_name
                       withBlock: (id) block
                          policy:(LokieHookPolicy) policy{
    SEL sel = NSSelectorFromString(selecctor_name);
    LOKIE_CHECK_ERROR(sel, @"unkown selector name");
    return lk_hook(self,Lokie_hook_func_type_class_member,
                   sel, block, policy);
}

+ (BOOL) Lokie_hookClassSelector:(NSString *) selecctor_name
                       withBlock: (id) block
                          policy:(LokieHookPolicy) policy{
    
    SEL sel = NSSelectorFromString(selecctor_name);
    LOKIE_CHECK_ERROR(sel, @"unkown selector name");
    return lk_hook(self,Lokie_hook_func_type_class_static,
                   sel, block, policy);
}

+ (BOOL) Lokie_resetSelector:(NSString *) selector_name
                    withType:(BOOL) isMember{
    SEL sel = NSSelectorFromString(selector_name);
    LOKIE_CHECK_ERROR(sel, @"unkown selector name");
    return lk_unhook(self, sel, isMember);
}

+ (NSArray *) LokieErrorStack{
    return LokieErrorStack();
}

@end
