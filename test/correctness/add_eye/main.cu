#include <iostream>
#include <random>
#include <type_traits>
#include <wmma_extension.hpp>

#ifndef TEST_ARCH
#define TEST_ARCH (-1)
#endif

constexpr std::size_t N = 16;

template <class T, class S>
__device__ __host__ T convert(const S);
template <> __device__ __host__ float convert<float, float>(const float a) {return a;}
template <> __device__ __host__ float convert<float, half >(const half  a) {return __half2float(a);}
template <> __device__ __host__ half  convert<half , float>(const float a) {return __float2half(a);}
template <> __device__ __host__ half  convert<half , half >(const half  a) {return a;}

__global__ void make_eye_kernel(float* const eye, const float a) {
	nvcuda::wmma::fragment<nvcuda::wmma::accumulator, N, N, N, float> frag_c;
	nvcuda::wmma::fill_fragment(frag_c, 1.0f);
	mtk::wmma::add_eye(frag_c, a);
	nvcuda::wmma::store_matrix_sync(eye, frag_c, N, nvcuda::wmma::mem_col_major);
}

void test() {
	std::printf("-- add_eye test --\n");
	std::printf("arch    : %d\n", TEST_ARCH);
	float *h;

	cudaMallocHost(&h, sizeof(float) * N * N);

	cudaDeviceSynchronize();
	make_eye_kernel<<<1, 32>>>(h, 2.0f);
	cudaDeviceSynchronize();

	double max_error = 0.0;
	for (unsigned i = 0; i < N; i++) {
		for (unsigned j = 0; j < N; j++) {
			const float c = (i == j) ? 3.0f : 1.0f;
			const double diff = c - h[i * 16 + j];
			max_error = std::max(max_error, std::abs(diff));
		}
	}
	std::printf("error   : %e\n", max_error);
}

int main() {
	test();
}
