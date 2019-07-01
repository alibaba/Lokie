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

#include "ffi.h"
#include <vector>

class LokieFunctionInterface{
public:
    typedef void (*FFI_FUNC_TYPE)(void);
    typedef void (*FFI_BIND_FUNC_TYPE)(ffi_cif*,void*,void**,void*);
    
public:
    LokieFunctionInterface()=default;
    ~LokieFunctionInterface()=default;
    
    bool init(std::vector<ffi_type *>&params, ffi_type *rtype);
    bool init(ffi_type **param, size_t count, ffi_type *rtype);
    
    bool invoke(FFI_FUNC_TYPE func, void *ret, void **params);
    ffi_closure *bind(void **address, FFI_BIND_FUNC_TYPE redirect,void *data);
    
public:
    inline ffi_type **types(){ return _cif.arg_types;}
    
protected:
    LokieFunctionInterface &operator=(const LokieFunctionInterface &) = delete;
    LokieFunctionInterface &operator=(const LokieFunctionInterface &&) = delete;
    LokieFunctionInterface(const LokieFunctionInterface &) = delete;
    
protected:
    ffi_cif _cif;
    std::vector<ffi_type *> _param_types;
};

