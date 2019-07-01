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

_Pragma("once")
#import "Lokie.h"
#include "ffi.h"
#import <objc/runtime.h>
#include <map>
#include <string>

typedef enum {
    Lokie_hook_func_type_class_static,
    Lokie_hook_func_type_class_member
}Lokie_hook_func_type;

class LokieHookAction{
public:
    LokieHookAction(id target, Class isa, SEL sel,  id block,
                    LokieHookPolicy policy, Lokie_hook_func_type htype);
    ~LokieHookAction();
    bool do_hook_class_member_func();
    bool execute_block(void *ret, void ** params, bool same, void * data);
    
public:
    LokieHookPolicy policy() const{ return _policy; }
    inline long     hash() const { return _hash; }
    inline long     sel_hash() const { return _selhash;}
    
protected:
    void get_param_encode(std::vector<std::string> &) const;
    void get_return_encode(std::string &) const;
    void get_param_encode_ffi(std::vector<ffi_type *>&) const;
    ffi_type* get_return_encode2ffi() const;
    NSMethodSignature *block_signature(id block);
    bool is_same_type_encoding(const std::string &lhs, const std::string &rhs);
    bool check_valid();
    
protected:
    LokieHookPolicy _policy;
    size_t            _hash;
    size_t            _selhash;
    
    Class _target_class = {nullptr};
    SEL  _selector = {nullptr};
    
    id _block = {nullptr};
    Lokie_hook_func_type _hookType;
    
    Method _method = {nullptr};
    uint   _method_param_count = {0};
    BOOL  _needDynamicOverride = {false};
    BOOL  _ishooked_before = {false};
    void  *_ctx = {nullptr};
    ffi_closure *_closure = {nullptr};
    
    IMP  _orgImplement = {nullptr};
    IMP  _perfectforwardImplement = {nullptr};
};
