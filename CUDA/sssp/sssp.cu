
#include <cuda.h>
#include <thrust/host_vector.h>
#include <thrust/device_vector.h>
#include <iostream>
#include <climits>
#include <fstream>
#include <sstream>
#include <chrono>

using namespace std;

const int max_dist = 1e6;

__global__
void relax(int* d_node_lock, int *d_all_bucket, int *d_bucket_id, int *d_n, int *d_head_bucket, int *d_tail_bucket, int *d_c, int *d_r, int *d_dist, int *d_delta){
    int thread  = blockIdx.x * blockDim.x + threadIdx.x;

    if(thread >= d_tail_bucket[(*d_bucket_id)] - d_head_bucket[(*d_bucket_id)]) return;

    int index = d_head_bucket[(*d_bucket_id)] + thread;
    index %= (*d_n);

//    printf("index %d\n", index);

    int d_u = d_all_bucket[(*d_bucket_id) * (*d_n) + index];

//    printf("%d d_u %d\n", thread, d_u);

    for(int i = d_r[d_u]; i < d_r[d_u+1]; i+=2){
        int d_v = d_c[i];
        int d_v_dist, d_v_bucket;

        bool updated_dist = 0;

        bool leave1 = 0;
        while (!leave1) {
            if(!atomicCAS(d_node_lock + d_v,0,1)){
              d_v_dist = d_dist[d_u]+d_c[i+1];
              d_v_bucket = d_v_dist/(*d_delta);

//              printf("%d d_v %d d_v_dist %d\n", thread, d_v, d_v_dist);

              if(d_dist[d_v] > d_v_dist){
                d_dist[d_v] = d_v_dist;
                updated_dist = 1;
              }
              leave1 = 1;
              d_node_lock[d_v] = 0;

              __threadfence();
            }
        }
        if(updated_dist){
          int tail = atomicInc((unsigned int*)(d_tail_bucket+d_v_bucket), (unsigned int)(*d_n));   //all vars should be int and int only
          d_all_bucket[d_v_bucket * (*d_n) + tail] = d_v;
          __threadfence();

//          bool leave2 = 0;
//          while (!leave2) {
//              if(!atomicCAS(d_lock + d_v_bucket,0,1)){

//                d_all_bucket[d_v_bucket * (*d_n) + d_tail_bucket[d_v_bucket]] = d_v;

//                d_tail_bucket[d_v_bucket]++;
//                d_tail_bucket[d_v_bucket]%=(*d_n);

//                leave2 = 1;                         //why doesn't break work???
//                d_lock[d_v_bucket] = 0;

//                __threadfence();
//              }
//          }
        }
    }
}

void read_adj_list(const string& filename, thrust::host_vector<int>& h_r, thrust::host_vector<int>& h_c) {
    ifstream file(filename);
    string line;

    int row_pointer = 0;
    while (getline(file, line)) {
        h_r.push_back(row_pointer);

        istringstream iss(line);
        int neighbor, weight;

        while (iss >> neighbor >> weight) {
            h_c.push_back(neighbor);
            h_c.push_back(weight);
            row_pointer+=2;
        }
    }
    h_r.push_back(row_pointer);
}

string get_arg(int argc, char *argv[], string arg_name){
    for(int i = 1; i < argc; i++){
        string arg_i = argv[i];
        if(arg_i == arg_name && i+1 < argc){
            string arg = argv[i+1];
            return arg;
        }
    }
    return "";
}

int main(int argc, char *argv[]){
    int src = 0;
    int delta = 3;
    int cnt_bucket = 32;
    int block_size = 1024;
    string graph_name = "100K";

    string arg;
    int temp;

    arg = get_arg(argc,argv,"-cb");
    if(arg != "" && (temp=stoi(arg))!=0) cnt_bucket = temp;

    arg = get_arg(argc,argv,"-del");
    if(arg != "" && (temp=stoi(arg))!=0) delta = temp;

    arg = get_arg(argc,argv,"-bs");
    if(arg != "" && (temp=stoi(arg))!=0) block_size = temp;

    arg = get_arg(argc,argv,"-g");
    if(arg != "") graph_name = arg;

    string filename = "connected_graph_"+graph_name+".txt";
    string output_file_name = "output_"+graph_name+"_"+to_string(block_size)+"_"+to_string(delta)+".txt";

    thrust::host_vector<int> h_r, h_c;

    read_adj_list(filename, h_r, h_c);

    int n = h_r.size()-1;

    // Some dummy vector to wake up device
    thrust::device_vector<int> dummy_vec (1000000, 1);

    auto start_time_cpy = chrono::high_resolution_clock::now();

    int *d_n;
    cudaMalloc((void**)&d_n , sizeof(int));
    cudaMemcpy(d_n, &n, sizeof(int), cudaMemcpyHostToDevice);

    int *d_delta;
    cudaMalloc((void**)&d_delta, sizeof(int));
    cudaMemcpy(d_delta, &delta, sizeof(int), cudaMemcpyHostToDevice);

    int *d_b_size;
    cudaMalloc((void**)&d_b_size, sizeof(int));

    int *d_curr;
    cudaMalloc((void**)&d_curr, sizeof(int));


//    thrust::device_vector<int> d_lock(cnt_bucket,0);
    thrust::device_vector<int> d_node_lock(n,0);


    thrust::device_vector<int> d_c(h_c);
    thrust::device_vector<int> d_r(h_r);

    thrust::device_vector<int> d_dist(n, max_dist);
    d_dist[src] = 0;

    thrust::device_vector<int> d_all_bucket(cnt_bucket*n);
    thrust::device_vector<int> d_head_bucket(cnt_bucket,0);
    thrust::device_vector<int> d_tail_bucket(cnt_bucket,0);   //next ptr after tail

    d_all_bucket[0*n + 0] = src;
    d_tail_bucket[0]++;                                       //use relax for this?

    auto stop_time_cpy = chrono::high_resolution_clock::now();
    auto duration_cpy = chrono::duration_cast<chrono::microseconds>(stop_time_cpy - start_time_cpy);

    auto start_time_kernel = chrono::high_resolution_clock::now();

    for(int curr = 0; curr < cnt_bucket; curr++){             //reusing empty buckets???
//    printf("bucket_id %d\n",curr);
      int b_size;
//      cout << "b_size" << d_tail_bucket[curr] - d_head_bucket[curr] << "\n";
      while(b_size = d_tail_bucket[curr] - d_head_bucket[curr]){

          cudaMemcpy(d_b_size, &b_size, sizeof(int), cudaMemcpyHostToDevice);
          cudaMemcpy(d_curr, &curr, sizeof(int), cudaMemcpyHostToDevice);

          relax<<<(b_size/block_size)+1, block_size>>>(thrust::raw_pointer_cast(d_node_lock.data()), thrust::raw_pointer_cast(d_all_bucket.data()), d_curr, d_n, thrust::raw_pointer_cast(d_head_bucket.data()), thrust::raw_pointer_cast(d_tail_bucket.data()), thrust::raw_pointer_cast(d_c.data()), thrust::raw_pointer_cast(d_r.data()), thrust::raw_pointer_cast(d_dist.data()), d_delta);
          cudaDeviceSynchronize();

//         printf("bucket \n");
//          for(int i = d_head_bucket[curr]; i < d_tail_bucket[curr]; i++){
//            printf("%d ", (int)d_all_bucket[curr*n + i]);
//          }
//          printf("\n");

          cudaError_t err = cudaGetLastError();
          if (err) {
              cerr << "Error: " << cudaGetErrorString(err) << "\n";
              return 1;
          }

          d_head_bucket[curr] += b_size;
          d_head_bucket[curr] %= n;
      }
    }

    auto stop_time_kernel = chrono::high_resolution_clock::now();
    auto duration_kernel = chrono::duration_cast<chrono::microseconds>(stop_time_kernel - start_time_kernel);

    ofstream output_file(output_file_name);

    if (!output_file.is_open()) {
        cerr << "Error: Unable to open output file." << endl;
        return 1;
    }

    output_file << "Delta Stepping Execution Time Kernel: " << duration_kernel.count()/1000.0 << " milliseconds" << endl;

    output_file << "Delta Stepping Time FULL: " << duration_kernel.count()/1000.0+duration_cpy.count()/1000.0 << " milliseconds" << endl;

    thrust::device_vector<int> dist(d_dist.begin(), d_dist.end());

    for (int i = 0; i < n; ++i) {
        output_file << "Distance to node " << i << ": " << dist[i] << endl;
    }

    output_file.close();

    cudaFree(d_n);
    cudaFree(d_delta);
    cudaFree(d_b_size);
    cudaFree(d_curr);

    return 0;
}
