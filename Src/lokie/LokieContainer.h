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

#ifndef LokieContainer_hpp
#define LokieContainer_hpp
#include <thread>
#include <map>
#include <vector>
#include <shared_mutex>
#include <iostream>

struct lokie_mutex{
public:
    inline void lock(){while(_flag.test_and_set(std::memory_order_acquire));}
    inline void unlock(){_flag.clear(std::memory_order_release);}
protected:
    lokie_mutex& operator=(const lokie_mutex&) = delete;
    lokie_mutex& operator=(lokie_mutex&&) = delete;
protected:
    std::atomic_flag _flag = ATOMIC_FLAG_INIT;
};

using  LOCK_TYPE = lokie_mutex;
using  GUARD_TYPE = std::lock_guard<LOCK_TYPE>;
template <template<class ...> class C, typename ... TYPES>
class LokieContainer;

template <typename K, typename V>
class LokieContainer<std::map, K, V> {
public:
    using  CTYPE = std::map<K,V>;
public:
    LokieContainer() = default;
    LokieContainer(std::initializer_list<std::pair<K, V>> l) {
        for (auto itr : l) _container.insert(itr);
    }
    
    template<typename ... ARGS>
    void insert(ARGS ... args){
        GUARD_TYPE guid(_lock);
        _container.emplace(std::forward<ARGS&&>(args)...);
    }
    
    auto find(K k){
        GUARD_TYPE guid(_lock);
        auto itr = _container.find(k);
        return  std::make_pair(itr != _container.end(), itr);
    }
    
    auto find(bool (^condition)(typename CTYPE::value_type)){
        assert(condition);
        GUARD_TYPE guid(_lock);
        auto itr = std::find_if(_container.begin(), _container.end(), condition);
        return  std::make_pair(itr != _container.end(), itr);
    }
    
    CTYPE copy(){
        GUARD_TYPE guid(_lock);
        return CTYPE(_container);
    }
    
    void erase(bool (^condition)(typename CTYPE::value_type)){
        assert( condition );
        GUARD_TYPE guid(_lock);
        auto itr = std::find_if(_container.begin(), _container.end(), condition);
        if (itr != _container.end()) {
            _container.erase(itr);
        }
    }
    
    void erase(K k){
        GUARD_TYPE guid(_lock);
        _container.erase(k);
    }
    
    void clear(){
        GUARD_TYPE guid(_lock);
        _container.clear();
    }
    
    size_t size() {
        GUARD_TYPE guid(_lock);
        return _container.size();
    }
protected:
    LokieContainer(const LokieContainer &) = delete;
    LokieContainer(const LokieContainer &&) = delete;
    LokieContainer & operator=(const LokieContainer &) = delete;
protected:
    CTYPE  _container;
    LOCK_TYPE _lock;
};

template <typename T>
class LokieContainer<std::vector, T> {
public:
    using  CTYPE = std::vector<T>;
public:
    LokieContainer() = default;
    LokieContainer(std::initializer_list<T> l) {
        for (auto itr : l) _container.push_back(itr);
    }
    
    template<typename ... ARGS>
    void insert(ARGS ... args){
        GUARD_TYPE guid(_lock);
        _container.push_back(std::forward<ARGS&&>(args)...);
    }
    
    void erase(bool (^condition)(typename CTYPE::value_type)){
        LOKIE_CHECK_NRT(condition);
        GUARD_TYPE guid(_lock);
        auto itr = std::find_if(_container.begin(), _container.end(), condition);
        if (itr != _container.end()) {
            _container.erase(itr);
        }
    }
    
     void erase(T n){
         GUARD_TYPE guid(_lock);
         auto itr = std::remove(_container.begin(), _container.end(), n);
         if (itr != _container.end()) {
             _container.erase(itr);
         }
    }
    
    CTYPE copy(){
        GUARD_TYPE guid(_lock);
        return CTYPE(_container);
    }
    
    void clear(){
        GUARD_TYPE guid(_lock);
        _container.clear();
    }
    
    size_t size(){
        GUARD_TYPE guid(_lock);
        return _container.size();
    }
    
    T &first(){
        GUARD_TYPE guid(_lock);
        return _container[0];
    }
    
protected:
    LokieContainer(const LokieContainer &) = delete;
    LokieContainer(const LokieContainer &&) = delete;
    LokieContainer & operator=(const LokieContainer &) = delete;
protected:
    CTYPE  _container;
    LOCK_TYPE _lock;
};

template<typename K, typename V>
using LokieTSMap = LokieContainer<std::map, K, V>;

template<typename T>
using LokieTSVector = LokieContainer<std::vector, T>;

#endif /* LokieContainer_hpp */

