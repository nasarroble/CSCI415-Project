#include<iostream>
#include<string>
#include<cstring>
#include<ctime>
#include<cstdlib>
#include<sys/time.h>
#include<stdio.h>
#include<iomanip>
/* we need these includes for CUDA's random number stuff */
#include<curand.h>
#include<curand_kernel.h>
using namespace std;


#define MAX 26

 //array of all possible password characters
int b[1000]; //array of attempted password cracks
unsigned long long tries = 0;
char alphabet[] = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' };

size_t result = 1000 * sizeof(float);

int *a = (int *) malloc(result);

void serial_passwordCrack(int length){
bool cracked = false;
do{
    b[0]++;
    for(int i =0; i<length; i++){
        if (b[i] >= 26 + alphabet[i]){ 
            b[i] -= 26; 
            b[i+1]++;
        }else break;
    }
    cracked=true;
    for(int k=0; k<length; k++)
        if(b[k]!=a[k]){
            cracked=false;
            break;
        }
    if( (tries & 0x7ffffff) == 0 )
        cout << "\r       \r   ";
    else if( (tries & 0x1ffffff) == 0 )
        cout << ".";
    tries++;
}while(cracked==false);

}


__global__ void parallel_passwordCrack(int length,int*d_output,int *a, long attempts )
{	
	int idx = blockIdx.x*blockDim.x+threadIdx.x;
	bool cracked = false;
	int mark=0;
        char alphabetTable[] = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' };        
	int newB[1000]; 

 // // randoms(states,alphabetTable,d_output);

 //  char alph ;//= 'a';
// while(!cracked){
//       alph =alphabetTable[rand()%26];
//        d_output[idx] = int(alph);
//      __syncthreads();
//       for(int i = 0; i< length; i++){
//         if(d_output[i] != a[i])
//         {
//           cracked = false;

//         }
//         else{
//           cracked = true;
//         }
//       }
//   }

__shared__ int nIter;
__shared__ int idT;


do{


//     newB[0]++;
        
//     if(mark<length){
//         if (newB[idx] >= 26 + alphabetTable[idx]){ 
//             newB[idx] -= 26; 
//             newB[idx+1]++;
//     }
// }else{
//         mark++;
//     }

   newB[0]++;
    for(int i =0; i<length; i++){
        if (newB[i] >= 26 + alphabetTable[i]){ 
            newB[i] -= 26; 
            newB[i+1]++;
        }else break;
    }
    
    cracked=true;
  //  nIter = 1;
    for(int k=0; k<length; k++)
    {
        if(newB[k]!=a[k]){
            cracked=false;
         //   nIter = 0;
            break;
        }else
        {
            cracked = true;
           // nIter = 1;
            // printf("idx:  %d  found\n", idx);
            //  d_output[k] = newB[k];

        }
    }
    if(cracked){
      __syncthreads();
      idT = idx;
      nIter = 1;
       __syncthreads();
      break;

    }
//    if( (tries & 0x7ffffff) == 0 )
//        cout << "\r       \r   ";
//    else if( (tries & 0x1ffffff) == 0 )
//        cout << ".";
    attempts++;
}while(!cracked);

if(idx == idT){
        for(int i = 0; i< length; i++){
  
             d_output[i] = newB[i];
    }


}

//newB[idx];


//    if( idx == 2 ){
//          nIter =idx+1;
//          printf("idx: %d: found, %d\n", idx, nIter);
//        }
// if(!nIter){
//   printf("idx: %d: not found \n", idx);
// }


}


long long start_timer() {
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return tv.tv_sec * 1000000 + tv.tv_usec;
}


// Prints the time elapsed since the specified time
long long stop_timer(long long start_time, std::string name) {
	struct timeval tv;
	gettimeofday(&tv, NULL);
	long long end_time = tv.tv_sec * 1000000 + tv.tv_usec;
        std::cout << std::setprecision(5);	
	std::cout << name << ": " << ((float) (end_time - start_time)) / (1000 * 1000) << " sec\n";
	return end_time - start_time;
}



int main()
{
int length; //length of password
int random; //random password to be generated
long attempts = 0; //number of attempts to crack the password
int *d_input = (int *) malloc(result);;


cout << "Enter a password length: ";
cin >> length;
int *h_gpu_result = (int*)malloc(1000*sizeof(int));

srand(time(NULL));
cout << "Random generated password: " << endl;
for (int i =0; i<length; i++){
    
        random = alphabet[(rand()%26)]; 
    
    a[i] = random; //adding random password to array
  //  d_input[i] = a[i];
    cout << char(a[i]);
}cout << "\n" << endl;

//declare GPU memory pointers
  int *d_output;
//allocate GPU memory
  cudaMalloc((void **) &d_output,1000*sizeof(int));
  cudaMalloc((void **) &d_input,result);
//transfer the array to the GP

  cudaError_t err = cudaSuccess;
err = cudaMemcpy(d_input, a,result,cudaMemcpyHostToDevice);
  if (err != cudaSuccess)
  {
    fprintf(stderr, "Failed to copy d_S from host to device (error code %s)!\n", cudaGetErrorString(err));
      exit(EXIT_FAILURE);
  }
//launch the kernel
int threards = length*10;//(length*1000)/1024;


   // for(int i = 0; i< length; i++){
   //  printf("value: %d\n", d_input[i]);
   // }
//    

/* CUDA's random number library uses curandState_t to keep track of the seed value
     we will store a random state for every thread  */
  curandState_t* states;

  /* allocate space on the GPU for the random states */
//  cudaMalloc((void**) &states, threards * sizeof(curandState_t));
    /* invoke the GPU to initialize all of the random states */
//   init<<<threards, threards>>>(time(0), states);


//parallel_passwordCrack<<<threards,1024>>>(length,d_output,d_input,attempts);
parallel_passwordCrack<<<1,threards>>>(length,d_output,d_input,attempts);
//copy back the result array to the CPU
cudaMemcpy(h_gpu_result,d_output,1000*sizeof(int),cudaMemcpyDeviceToHost);

// cout << "Serial Password Cracked: " << endl;
// serial_passwordCrack(length);
// cout << "\n";
// for(int i=0; i<length; i++){
//     cout << char(b[i]);
// }cout << "\nNumber of tries: " << tries << endl;

cout << "\nParallel Password Cracked: " << endl;
for(int i=0; i<length; i++){
//	cout << char(h_gpu_result[i]);
    printf("%c\n", char(h_gpu_result[i]));
}
cout << "\nNumber of attempts: " << attempts << endl;

cudaFree(d_output);
cudaFree(d_input);
cudaFree(states);
free(h_gpu_result);

return 0;
}
