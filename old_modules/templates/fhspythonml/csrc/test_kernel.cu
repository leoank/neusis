#define TILE_DIM 32

__global__ void matmul_kernel(float* pfMatrixA, float* pfMatrixB, float* pfMatrixC, int m, int k, int n)
{
    int nRow = blockIdx.y * blockDim.y + threadIdx.y;
    int nCol = blockIdx.x * blockDim.x + threadIdx.x;
    float sum = 0.0f;

    for(int i =0; i < k; i++)
    {
        sum += pfMatrixA[nRow * k + i] * pfMatrixB[i * n + nCol];
    }
    pfMatrixC[nRow * n + nCol] = sum;
}

void launch_matmul(
                    float* array_A,
                    float* array_B,
                    float* array_C,
                    int M,
                    int K,
                    int N
                    )
{
    dim3 block_size(TILE_DIM, TILE_DIM);
    dim3 grid_size((M + TILE_DIM - 1) / TILE_DIM, (N + TILE_DIM - 1) / TILE_DIM);
    matmul_kernel<<<grid_size, block_size>>>(array_A, array_B, array_C, M, K, N);
}
