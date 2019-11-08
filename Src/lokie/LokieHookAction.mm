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

#include "LokieHookAction.h"
#include "LokieInvokation.h"
#include "LokieMicro.h"
#include "LokieHookActionContainer.h"
#include <thread>
#include <list>
#define  DEFAULT_ENCODING_LENGTH  32
std::mutex g_init_mutex;
std::hash<std::string> hash_func;

static std::list<size_t> g_listForbidden = {hash_func("alloc")};

constexpr std::size_t LOKIE_UINT_BIT = CHAR_BIT * sizeof(std::size_t);
inline constexpr std::size_t LOKIE_INT_ROTATE(NSInteger var, size_t pos){
    return var << pos | var >> (LOKIE_UINT_BIT - pos);
}

extern "C" {
    void LokieSetError(NSString *);
    void Lokie_perfect_forword(ffi_cif *cif, void *ret, void **args, void *user_info);

    std::size_t
    LokieActionIdentifier( __unsafe_unretained Class isa, id target,
                          Lokie_hook_func_type htype){
        return LOKIE_INT_ROTATE((std::size_t)isa, LOKIE_UINT_BIT/2) ^ (std::size_t)htype;
    }
}

static std::map<size_t, ffi_type *> g_ffi_oc_type_entry={
    {hash_func("@?"), &ffi_type_pointer},  //! @?
    {hash_func("v"), &ffi_type_void},      //! v
    {hash_func("c"), &ffi_type_schar},     //! c
    {hash_func("C"),  &ffi_type_uchar},    //! C
    {hash_func("s"), &ffi_type_sshort},    //! s
    {hash_func("S"), &ffi_type_ushort},    //! S
    {hash_func("i"), &ffi_type_sint},      //! i
    {hash_func("I"), &ffi_type_uint},      //! I
    {hash_func("l"), &ffi_type_slong},     //! l
    {hash_func("L"), &ffi_type_ulong},     //! L
    {hash_func("q"), &ffi_type_sint64},    //! q
    {hash_func("Q"), &ffi_type_uint64},    //! Q
    {hash_func("f"), &ffi_type_float},     //! f
    {hash_func("d"), &ffi_type_double},    //! d
    {hash_func("F"), &ffi_type_double},    //! F
    {hash_func("B"), &ffi_type_uint8},     //! B
    {hash_func("^"), &ffi_type_pointer},   //! ^
    {hash_func("@"), &ffi_type_pointer},   //! @
    {hash_func("#"), &ffi_type_pointer},   //! #
    {hash_func(":"), &ffi_type_schar},     //! :
};

static ffi_type *get_ffi_type(std::string &encode){
    auto itr = g_ffi_oc_type_entry.find(hash_func(encode));
    return (itr != g_ffi_oc_type_entry.end()) ? itr->second : nullptr;
}

LokieHookAction::LokieHookAction(id target, Class isa, SEL sel,  id block,
                                 LokieHookPolicy policy, Lokie_hook_func_type htype)
:_perfectforwardImplement(nullptr), _target_class(isa),_selector(sel),_block(block),
_policy(policy), _hookType(htype){    
    std::lock_guard<std::mutex> lock(g_init_mutex);
    Class super_class = class_getSuperclass(_target_class);
    Method super_method = NULL;

    _hash = LokieActionIdentifier(isa, target, htype);
    _selhash = hash_func(sel_getName(sel));
    
    auto get_method = (Lokie_hook_func_type_class_static == htype) ? class_getClassMethod : class_getInstanceMethod;
    
    _method = get_method(isa, sel);
    _method_param_count = method_getNumberOfArguments(_method);
    super_method = get_method(super_class, sel);
    
    _needDynamicOverride = NO;
    if (_method && (_method == super_method)){
        _needDynamicOverride = YES;
    }
    
    LokieHookContexts *c= LokieHookContexts::instance();
    _orgImplement = c->get_imp(_hash, _selhash);
    
    if (_orgImplement) {
        _ishooked_before = YES;
        _ctx = c->get_context(_orgImplement);
    }else{
        LOKIE_CHECK_NRT(_method);
        _orgImplement = method_getImplementation(_method);
        LOKIE_CHECK_NRT(_orgImplement);
        _ctx = c->insert(_orgImplement, _hash, _selhash);
    }
}

LokieHookAction::~LokieHookAction(){
    if (_closure) {
        ffi_closure_free(_closure);
        _closure = NULL;
    }
}

void
LokieHookAction::get_param_encode(std::vector<std::string> &list) const{
    assert(_method); assert(list.empty());
    unsigned int count = method_getNumberOfArguments(_method);
    list.reserve(count);
    for (unsigned int i = 0; i < count; i++){
        char type[DEFAULT_ENCODING_LENGTH] = {0};
        method_getArgumentType(_method, i, type, DEFAULT_ENCODING_LENGTH);
        list.push_back(type);
    }
}

void
LokieHookAction::get_return_encode(std::string &s) const{
    assert(_method);
    char type[DEFAULT_ENCODING_LENGTH] ={0};
    method_getReturnType(_method, type, DEFAULT_ENCODING_LENGTH);
    s = type;
}

void
LokieHookAction::get_param_encode_ffi(std::vector<ffi_type *>& types) const{
    std::vector<std::string> plist;
    this->get_param_encode(plist);
    if (plist.empty()) {
        types.push_back(&ffi_type_void);
        return;
    }
    
    types.reserve(plist.size());
    for (auto item : plist) {
        types.push_back(get_ffi_type(item));
    }
}

ffi_type*
LokieHookAction::get_return_encode2ffi() const{
    std::string ret_type;
    this->get_return_encode(ret_type);
    return get_ffi_type(ret_type);
}

NSMethodSignature *
LokieHookAction::block_signature(id block){
    LokiBlockRef  ref = (__bridge  LokiBlockRef)(block);
    LOKIE_CHECK_ERROR_NIL(ref->flags & LokieBlockFlagsHasSignature, @"does not have signature")
    
    unsigned char *desc = (unsigned char *)ref->descriptor;
    desc += 2 * sizeof(unsigned long int);
    if (ref->flags & LokieBlockFlagsHasCopyDisposeHelpers) {
        desc += 2 * sizeof(void *);
    }
    
    LOKIE_CHECK_ERROR_NIL(desc, @"block does not have a signature");
    const char *signature = (*(const char **)desc);
    
    LOKIE_CHECK_ERROR_NIL(signature, @"block does not have a signature");
    return [NSMethodSignature signatureWithObjCTypes:signature];
}

bool
LokieHookAction::is_same_type_encoding(const std::string &lhs, const std::string &rhs){
    LOKIE_CHECK_RETURN(!(lhs == rhs), YES);
    LOKIE_CHECK_RETURN(lhs == "@", NO);
    return (0 == rhs.rfind("@", 0));
}

bool
LokieHookAction::check_valid(){
    LOKIE_CHECK_ERROR(_method, @"not find selector");
    LOKIE_CHECK_ERROR(_block, @"block can't be null");
    LOKIE_CHECK_ERROR((std::find(g_listForbidden.begin(),
                                g_listForbidden.end(), _selhash) == g_listForbidden.end()),
                      @"selector is forbidden");
    NSMethodSignature *blockSignature = this->block_signature(_block);
    LOKIE_CHECK_ERROR(blockSignature, @"abtain block signature return error");
    
    const char *encode =  method_getTypeEncoding(_method);
    LOKIE_CHECK_ERROR(encode, @"selector typeencode return NULL");
    
    NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:encode];
    LOKIE_CHECK_ERROR(methodSignature, @"selector signature return error");
    
    //! check count
    if ([methodSignature numberOfArguments] != [blockSignature numberOfArguments]){
        NSString *error = [NSString stringWithFormat:@"block 参数个数与selector[%@]不同", NSStringFromSelector(_selector) ];
        LOKIE_ERROR(error);
        return NO;
    }
    
    //! check type
    NSString *sel_rtype = [NSString stringWithUTF8String:[methodSignature methodReturnType]];
    NSString *block_rtype = [NSString stringWithUTF8String:[blockSignature methodReturnType]];
    if (_policy & LokieHookPolicyBefore || (_policy & LokieHookPolicyAfter)){
        LOKIE_CHECK_ERROR([block_rtype isEqualToString:@"v"], @"block return type should be void");
    }else if(_policy & LokieHookPolicyReplace){
        LOKIE_CHECK_ERROR([block_rtype isEqualToString: sel_rtype ], @"block return type should be void");
    }
    
    //! check 2... 参数类型
    NSInteger count = [methodSignature numberOfArguments];
    for (NSInteger index = 2; index < count; index ++ ){
        std::string lhs([methodSignature getArgumentTypeAtIndex:index]);
        std::string rhs([blockSignature  getArgumentTypeAtIndex:index]);
        
        //！fix: 参数列表存在block时不一致问题 （多谢 ruikaili 提出这个问题）
        if (rhs.find("@?") == 0) rhs="@?";
        
        this->is_same_type_encoding(lhs, rhs);
        LOKIE_CHECK_ERROR(this->is_same_type_encoding(lhs, rhs), @"block和selector参数类型不匹配");
    }
    
    //！ check block 第2个参数，必须是对象
    std::string p([blockSignature getArgumentTypeAtIndex:1]);
    LOKIE_CHECK_ERROR(p == "@",@"block第一个参数必须为id");
    
    return YES;
}

bool
LokieHookAction::do_hook_class_member_func(){
    LOKIE_CHECK_ERROR(check_valid(), @"action checkValid return FALSE");
    LOKIE_CHECK_ERROR(_method, @"_method can't be NULL");
    
    LokieHookContexts *c = LokieHookContexts::instance();
    void *ctx = c->get_context(_orgImplement);
    LOKIE_CHECK_ERROR(ctx, @"can't find ctx from _orgImplement");
    
    LokieFunctionInterface *pffi = (LokieFunctionInterface *) LokieHookContexts::get_cxt_ffi(ctx);
    ffi_type *rtype = this->get_return_encode2ffi();
    
    std::vector<ffi_type *> types;
    this->get_param_encode_ffi(types);
    
    bool init = pffi->init(types, rtype);
    LOKIE_CHECK_RETURN(init, NO);
    
    //! 对于同一个方法，如果绑定过了，就无需再多次绑定了
    if (_ishooked_before) return YES;
    _closure = pffi->bind((void **)&_perfectforwardImplement,
                        Lokie_perfect_forword, (void *)_orgImplement);
    LOKIE_CHECK_RETURN(_closure, NO);
    {
        std::lock_guard<std::mutex> lock(g_init_mutex);
        if (_needDynamicOverride) {
            class_addMethod(_target_class, _selector, _perfectforwardImplement, method_getTypeEncoding(_method));
        }else{
            method_setImplementation(_method, _perfectforwardImplement);
        }
    }
    
    return YES;
}

bool
LokieHookAction::execute_block(void *ret, void ** params, bool same, void * data){
    LokiBlockRef blockRef = (__bridge LokiBlockRef )_block;
    LOKIE_CHECK_ERROR(blockRef && blockRef->invoke, @"invalid block object");
    
    uint sel_param_cout = _method_param_count - 2;
    uint block_param_count = sel_param_cout + 2;
    
    ffi_type *type_list[30] = {&ffi_type_pointer, &ffi_type_pointer};
    void **ffiArgs = (void **)alloca(sizeof(void *) *block_param_count);
    ffiArgs[0] = alloca(type_list[0]->size);
    ffiArgs[1] = alloca(type_list[1]->size);
    LOKIE_CHECK_ERROR(ffiArgs && ffiArgs[0] && ffiArgs[1], @"out of memory");
    
    LokiBlockRef *first_ptr = (LokiBlockRef *)ffiArgs[0];
    *first_ptr = blockRef;
    void **second_ptr = (void **)ffiArgs[1];
    *second_ptr = data;
    
    LokieFunctionInterface *pffi = (LokieFunctionInterface *) LokieHookContexts::get_cxt_ffi(_ctx);
    
    for (int i=0; i<sel_param_cout; i++){
        type_list[i+2] = pffi->types()[i+2];
        ffiArgs[i+2] = params[i+2];
    }
    
    ffi_type *rtType = &ffi_type_void;
    if (same) {
        rtType = this->get_return_encode2ffi();
    }
    
    LokieFunctionInterface lif;
    LOKIE_CHECK_RETURN(lif.init(type_list, block_param_count, rtType), NO);
    return lif.invoke((LokieFunctionInterface::FFI_FUNC_TYPE)(blockRef->invoke), ret, ffiArgs);
}
