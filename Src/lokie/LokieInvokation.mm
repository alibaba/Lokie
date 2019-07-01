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

#include "LokieInvokation.h"
#import "LokieMicro.h"

bool
LokieFunctionInterface::init(std::vector<ffi_type *>&params, ffi_type *rtype){
    _param_types.swap(params);
    return this->init(&_param_types[0], _param_types.size(), rtype);
}

bool
LokieFunctionInterface::init(ffi_type **param, size_t count, ffi_type *rtype){
    LOKIE_CHECK_ERROR_RET(param, @"invalid params", false);
    LOKIE_CHECK_ERROR_RET(rtype, @"invalid rtype = NULL", false);
    ffi_status status = ffi_prep_cif(&_cif,FFI_DEFAULT_ABI,
                                     (unsigned int)count, rtype, param);
    LOKIE_CHECK_ERROR_RET(FFI_OK == status, @"ffi_prep_cif return error", false);
    return true;
}

bool
LokieFunctionInterface::invoke(FFI_FUNC_TYPE func, void *ret, void **params){
   LOKIE_CHECK_ERROR_RET(func, @"invoke::param func should not be null", false);
   LOKIE_CHECK_ERROR_RET(ret, @"invoke::param ret should not be null", false);
   LOKIE_CHECK_ERROR_RET(params, @"invoke::param params should not be null", false);
   ffi_call(&_cif, func, ret, params);
   return true;
}

ffi_closure *
LokieFunctionInterface::bind(void **address, FFI_BIND_FUNC_TYPE redirect, void *data){
    LOKIE_CHECK_ERROR_RET(address, @"param address is null", nullptr);
    LOKIE_CHECK_ERROR_RET(redirect, @"param redirect is null", nullptr);
    
    ffi_closure *result = (ffi_closure *)ffi_closure_alloc(sizeof(ffi_closure), address);
    LOKIE_CHECK_ERROR_RET(result, @"ffi_closure_alloc return null", nullptr);
    
    ffi_status status = ffi_prep_closure_loc(result, &_cif, redirect, data, *address);
    if (status != FFI_OK) {
        ffi_closure_free(result);
        LOKIE_ERROR(@"ffi_prep_closure_loc return error");
        result = nullptr;
    }
    return result;
}
