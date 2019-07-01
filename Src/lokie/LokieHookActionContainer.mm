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

#include "LokieHookActionContainer.h"
#include "LokieHookAction.h"
#include "LokieInvokation.h"
#import <objc/runtime.h>
#import "LokieMicro.h"

#define INVALID_HASH (0)
extern std::hash<std::string> hash_func;

static size_t  g_dealloc_hash = hash_func("dealloc");

typedef struct {
    LokieFunctionInterface *ffi = {nullptr};
    std::size_t actionId = {INVALID_HASH};
    std::size_t sel_hash = {INVALID_HASH};
}LokieHookContext;

///////////////////////////////////////////////////////////////////////////////
//! LokieNode
class LokieNode{
public:
    void insert(SP<LokieHookAction>& obj) {
        if (!obj)  return;
        auto itr = _list.find(obj->policy());
        if (itr != _list.end()) {
            itr->second->insert(obj);
        }
    }
    inline SP<LokieArray> list(LokieHookPolicy policy){
        auto itr = _list.find(policy);
        if (itr != _list.end()) {
            return itr->second;
        }
        return nullptr;
    }
protected:
    using CTYPE = std::map<LokieHookPolicy, SP<LokieArray>>;
    CTYPE _list = {
        {LokieHookPolicyBefore, SP<LokieArray>(new LokieArray)},
        {LokieHookPolicyAfter, SP<LokieArray>(new LokieArray)},
        {LokieHookPolicyReplace, SP<LokieArray>(new LokieArray)},
    };
};

///////////////////////////////////////////////////////////////////////////////
//! LokieHookActionContainer

LokieHookActionContainer *
LokieHookActionContainer::instance(){
    static LokieHookActionContainer *inst =  new LokieHookActionContainer;
    return inst;
}

void
LokieHookActionContainer::add(SP<LokieHookAction> obj){
    long hash = obj->hash();
    SP<LokieNodeEntry> node_entry;
    
    //! 基于class做一次分类
    auto itr = _entry.find(hash);
    if (!itr.first){
        node_entry = decltype(node_entry)(new LokieNodeEntry);
        _entry.insert(hash, node_entry);
    }else{
        node_entry = itr.second->second;
    }
    
    //！ 基于selector做一次分类
    SP<LokieNode> node;
    auto sel_itr = node_entry->find(obj->sel_hash());
    if (!sel_itr.first) {
        node = decltype(node)(new LokieNode);
        node_entry->insert(obj->sel_hash(), node);
    }else{
        node = sel_itr.second->second;
    }
    node->insert(obj);
}

void
LokieHookActionContainer::remove(size_t hash){
    _entry.erase( [=](decltype(_entry)::CTYPE::value_type itr ) {
        return hash == itr.first;
    });
}

SP<LokieNode>
LokieHookActionContainer::get_hook_node(size_t hash, size_t sel_hash){
    auto itr  = _entry.find(hash);
    if (!itr.first) return nullptr;
    
    auto node_itr = itr.second->second->find(sel_hash);
    if (!node_itr.first) return nullptr;
    
    return node_itr.second->second;
}

bool
LokieHookActionContainer::execute(void *ret, void **args, void *user_info){
    size_t sel_hash = hash_func(sel_getName(*(SEL *)args[1]));
    void *target  = *(void **)args[0];
    IMP orgImpl = (IMP)user_info;

    LokieHookContexts *container = LokieHookContexts::instance();
    void *context = container->get_context(orgImpl);

    LOKIE_CHECK_ERROR_RET(context, @"invalid orgImpl", false);
    size_t hash = LokieHookContexts::get_cxt_hash(context);

    auto node = this->get_hook_node(hash, sel_hash);
    auto list = node->list(LokieHookPolicyReplace)->copy();
    if (!list.empty() ) {
        auto action = list.front();
        return action->execute_block(ret, args, true, target);
    }

    list = node->list(LokieHookPolicyBefore)->copy();
    for (auto &item : list) {
        item->execute_block(ret, args, NO, target);
    }
    
    LokieFunctionInterface *pffi = LokieHookContexts::get_cxt_ffi(context);
    pffi->invoke(orgImpl, ret, args);

    //! after dealloc, object is destroyed
    if (g_dealloc_hash == sel_hash){
        return true;
    }

    list = node->list(LokieHookPolicyAfter)->copy();
    for (auto &item : list) {
        item->execute_block(ret, args, NO, target);
    }
    return true;
}
///////////////////////////////////////////////////////////////////////////////
//! LokieHookContexts
LokieHookContexts *
LokieHookContexts::instance(){
    static LokieHookContexts *inst =  new LokieHookContexts;
    return inst;
}

void *
LokieHookContexts::get_context(IMP imp){
    auto itr = _list.find(imp);
    return itr.first ? itr.second->second : nullptr;
}

void
LokieHookContexts::remove_context(IMP imp){
    auto result = _list.find(imp);
    if (!result.first) return;
    
    auto itr = result.second;
    LokieHookContext *ctx = (LokieHookContext *)itr->second;
    delete ctx->ffi;
    delete ctx;
    _list.erase(imp);
}

void *
LokieHookContexts::insert(IMP imp, std::size_t hash, std::size_t sel_hash){
    LokieHookContext *ctx = new LokieHookContext;
    ctx->ffi = new LokieFunctionInterface;
    ctx->actionId = hash;
    ctx->sel_hash = sel_hash;
    _list.insert(imp, ctx);
    return ctx;
}

IMP
LokieHookContexts::get_imp(std::size_t hash, std::size_t sel_hash){
    auto res = _list.find([=](decltype(_list)::CTYPE::value_type node){
        LokieHookContext *ctx = (LokieHookContext *)node.second;
        return (ctx->actionId == hash && ctx->sel_hash == sel_hash);
    });
    return res.first ? res.second->first : nullptr;
}

long
LokieHookContexts::get_cxt_hash(void *ctx){
    LOKIE_CHECK_ERROR_RET(ctx, @"Invalid param", INVALID_HASH);
    LokieHookContext *c = (LokieHookContext *)ctx;
    return c->actionId;
}

LokieFunctionInterface *
LokieHookContexts::get_cxt_ffi(void *ctx){
    LOKIE_CHECK_ERROR_RET(ctx, @"Invalid param", nil);
    LokieHookContext *c = (LokieHookContext *)ctx;
    return c->ffi;
}


