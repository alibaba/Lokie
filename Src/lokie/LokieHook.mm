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

#include "ffi.h"
#import "Lokie.h"
#include "LokieMicro.h"
#include "LokieHookAction.h"
#include "LokieHookActionContainer.h"

BEGIN_DECLERE_C

extern std::mutex g_init_mutex;
extern std::hash<std::string> hash_func;

extern size_t LokieActionIdentifier( __unsafe_unretained Class isa, id target,
                                    Lokie_hook_func_type htype);
////////////////////////////////////////////////////////////////////////////////
//! hook function declaration
typedef BOOL (* LOKIE_HOOK_FUNC)(id, SEL, id ,LokieHookPolicy,
Lokie_hook_func_type);

BOOL
lk_hook_class(id self,SEL sel, id block,
              LokieHookPolicy policy, Lokie_hook_func_type htype);

void
Lokie_perfect_forword(ffi_cif *cif, void *ret, void **args, void *user_info);

BOOL
lk_unhook(id self, SEL sel, BOOL ismember);
////////////////////////////////////////////////////////////////////////////////
//! hook function implementation
BOOL
lk_hook(id self, Lokie_hook_func_type ftype,
        SEL sel, id block, LokieHookPolicy policy){
    using  HOOK_ENTRY = std::map<Lokie_hook_func_type, LOKIE_HOOK_FUNC>;
    static HOOK_ENTRY hookEntry = {
        { Lokie_hook_func_type_class_member, lk_hook_class},
        { Lokie_hook_func_type_class_static, lk_hook_class},
    };
    
    auto itr = hookEntry.find(ftype);
    if ( itr != hookEntry.end( )) {
        return itr->second(self, sel, block, policy, ftype);
    }
    
    //! ftype must be Lokie_hook_func_type
    NSString *string = [NSString stringWithFormat:@"unexpected ftype: %d", ftype];
    LokieSetError(string);
    return NO;
}

BOOL
lk_hook_class(id self, SEL sel, id block, LokieHookPolicy policy,
              Lokie_hook_func_type htype){
    using ActionPtr = std::shared_ptr<LokieHookAction>;
    ActionPtr action = ActionPtr(new LokieHookAction(nullptr,
                                                     self, sel, block, policy, htype));
    LOKIE_CHECK_ERROR(action->do_hook_class_member_func(), @"action doHookClassMemberFunc return FALSE");
    LokieHookActionContainer::instance()->add(action);
    return YES;
}

void
Lokie_perfect_forword(ffi_cif *cif, void *ret, void **args, void *user_info){
    LokieHookActionContainer::instance()->execute(ret, args, user_info);
}

BOOL lk_unhook(id self, SEL sel, BOOL ismember){
    Lokie_hook_func_type htype = ismember ? Lokie_hook_func_type_class_member
    : Lokie_hook_func_type_class_static;
    size_t hash = LokieActionIdentifier(self, nil, htype);
    
    Method method = nullptr;
    if ( Lokie_hook_func_type_class_static == htype ){
        method = class_getClassMethod(self, sel);
    }else if ( Lokie_hook_func_type_class_member == htype ){
        method = class_getInstanceMethod(self, sel);
    }else{
        method = class_getInstanceMethod(self, sel);
    }
    LOKIE_CHECK_ERROR(method, @"method is not fine");
    
    LokieHookContexts *c = LokieHookContexts::instance();
    size_t sel_hash = hash_func(sel_getName(sel));
    IMP orgImplement = c->get_imp(hash, sel_hash);
    LOKIE_CHECK_ERROR(orgImplement, @"function is not hooked before");
    c->remove_context(orgImplement);
    
    //! reset impl
    {
       std::lock_guard<std::mutex> guid(g_init_mutex);
        method_setImplementation(method, orgImplement);
    }
    
    //! reset container
    LokieHookActionContainer::instance()->remove(hash);
    return YES;
}
END_DECLERE_C
