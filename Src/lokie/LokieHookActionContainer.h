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
#include "LokieContainer.h"

class LokieNode;
class LokieHookAction;
class LokieFunctionInterface;

template<typename T> using SP = std::shared_ptr<T>;
using LokieArray = LokieTSVector<SP<LokieHookAction>>;
using LokieNodeEntry = LokieTSMap<std::size_t, SP<LokieNode>>;
using LokieActionEntry = LokieTSMap<std::size_t, SP<LokieNodeEntry>>;


class LokieHookActionContainer{
public:
    static  LokieHookActionContainer *instance();
public:
    void add(SP<LokieHookAction>);
    void remove(size_t hash);
    bool execute(void *ret, void **args, void *user_info);
protected:
    SP<LokieNode> get_hook_node(size_t hash, size_t sel_hash);
protected:
    LokieActionEntry _entry;
};

class LokieHookContexts{
    using LIST_TYPE = LokieTSMap<IMP, void *>;
public:
    static LokieHookContexts *instance();
    static long   get_cxt_hash(void *ctx);
    static LokieFunctionInterface *  get_cxt_ffi(void *ctx);
    
    void *  get_context(IMP);
    void    remove_context(IMP);
    
    void*   insert(IMP, std::size_t hash, std::size_t sel_hash);
    IMP     get_imp(std::size_t hash, std::size_t sel_hash);
protected:
    LIST_TYPE _list;
};
