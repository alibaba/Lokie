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

#ifndef LokieMicro_h
#define LokieMicro_h

extern "C"{
    void LokieSetError(NSString *);
    NSArray *LokieErrorStack();
}

#define LOKIE_ERROR(err) { \
    NSString *__lokie_temp = [NSString stringWithFormat:@">Lokie< %s[%d]:%@", __func__, __LINE__, err]; \
    LokieSetError(__lokie_temp); \
}

#define LOKIE_CHECK_ERROR_RET(con, desc, ret) {    \
                 if ( !(con) ) {                   \
                     LOKIE_ERROR(desc);            \
                     return (ret);                 \
}}

#define LOKIE_CHECK_ERROR_NRET(con, desc) {        \
        if ( !(con) ) {                            \
            LOKIE_ERROR(desc);                     \
            return;                                \
}}

#define LOKIE_CHECK_RETURN(con, ret) {  if (!(con)) { return (ret); }}
#define LOKIE_CHECK_NRT(con) {  if (!(con)) { return; }}
#define LOKIE_CHECK_ERROR(con, desc) LOKIE_CHECK_ERROR_RET(con, desc, NO)
#define LOKIE_CHECK_ERROR_NIL(con, desc) LOKIE_CHECK_ERROR_RET(con, desc, nil)

#define BEGIN_DECLERE_C  extern "C" {
#define END_DECLERE_C   }

////////////////////////////////////////////////////////////////////////////////
//! typedefs
typedef NS_OPTIONS(int, LokieBlockFlags) {
    LokieBlockFlagsHasCopyDisposeHelpers = (1 << 25),
    LokieBlockFlagsHasSignature          = (1 << 30)
};

typedef struct LokiBlock{
    __unused Class isa;
    LokieBlockFlags flags;
    __unused int reserved;
    void (__unused *invoke)(struct LokiBlock *block, ...);
    struct {
        unsigned long int reserved;
        unsigned long int size;
        // requires AspectBlockFlagsHasCopyDisposeHelpers
        void (*copy)(void *dst, const void *src);
        void (*dispose)(const void *);
        // requires AspectBlockFlagsHasSignature
        const char *signature;
        const char *layout;
    } *descriptor;
    // imported variables
} *LokiBlockRef;

#endif /* LokieMicro_h */
