#include <bits/stdc++.h>
using namespace std;


// CUSTOM HASH

#include <ext/pb_ds/assoc_container.hpp>
using namespace __gnu_pbds;
const uint64_t SEED = chrono::high_resolution_clock::now().time_since_epoch().count();
struct chash {
    static uint64_t splitmix64(uint64_t x) {
        x += 0x9e3779b97f4a7c15;
        x = (x ^ (x >> 30)) * 0xbf58476d1ce4e5b9;
        x = (x ^ (x >> 27)) * 0x94d049bb133111eb;
        return x ^ (x >> 31);
    }
	static void hash_combine(size_t& h1,size_t h2) {
		h1 = h1 ^ (h2 + 0x9e3779b97f4a7c15 + (h1 << 6) + (h1 >> 2));
	}
	
    size_t operator()(uint64_t x) const {
        return splitmix64(x + SEED);
    }
	size_t operator()(const pair<uint64_t,uint64_t>& p) const {
		size_t h = chash{}(p.first);
		hash_combine(h,chash{}(p.second));
		return h;
	}
};


// DEBUG

#ifdef LOCAL
struct {
    template<typename T>
    void __print(const T& x) {
        if constexpr (is_arithmetic_v<T> or is_same_v<T,string>)   cerr << x;
        else {
            cerr << '{';
            int f = 0; for(auto i : x) cerr << (f ++ ? "," : ""),__print(i);
            cerr << '}';
        }
    }
    template<typename X,typename Y>
    void __print(const pair<X,Y>& x){
        cerr << '{',__print(x.first),cerr << ",",__print(x.second),cerr << '}';
    }
    template <typename... A>
    void _print(const A&... a) {((__print(a),cerr << ","),...);}
}_d;
#define debug(...) cerr << "[" << #__VA_ARGS__ << "] = ["; _d._print(__VA_ARGS__); cerr << "]\n";
#else
#define debug(...)
#endif


// OTHER

#define USE_LONGS // comment out to use ints
#ifdef USE_LONGS
#define int long long
constexpr int INF = LONG_LONG_MAX; // ~9e18
#else
constexpr int INF = INT_MAX;
#endif

mt19937_64 rng(SEED);
int crand(int l,int r) { // random in [l,r]
	return uniform_int_distribution<int>(l,r)(rng);
}


// SOLUTION

int32_t main() {
	cin.tie(nullptr);
	ios_base::sync_with_stdio(false);

// #ifndef LOCAL
// 	freopen("in.in","r",stdin);
// 	freopen("out.out","w",stdout);
// #endif

	// TODO
}
