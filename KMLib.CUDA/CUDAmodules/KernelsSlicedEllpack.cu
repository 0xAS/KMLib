﻿/*
author: Krzysztof Sopyla
mail: krzysztofsopyla@gmail.com
License: MIT
web page: http://wmii.uwm.edu.pl/~ksopyla/projects/svm-net-with-cuda-kmlib/
*/

#include <float.h>

#include <Config.h>


#define ThreadPerRow 4
#define LOG_THREADS 2 // LOG2(ThreadPerRow)
#define SliceSize 64

//__device__ const int ThreadPerRow=2;
//define LOG_THREADS 1 // LOG2(ThreadPerRow)


//__device__ const int PREFETCH=2;





//gamma parameter in RBF
//__constant__ float GammaDev=0.5;

extern __shared__  float sh_data[];

//Use sliced Ellpack format for computing rbf kernel
//vecVals - vectors values in Sliced Ellpack,
//vecCols - array containning column indexes for non zero elements
//vecLengths  - number of non zero elements in row
//sliceStart   - determine where particular slice starts and ends
//selfDot    - precomputed self dot product
//result  - for final result
//mainVecIdx - index of main vector
//nrows   - number of rows
//ali	  - align
extern "C" __global__ void rbfSlicedEllpackKernel(const float *vecVals,
	const int *vecCols,
	const int *vecLengths, 
	const int * sliceStart, 
	const float* selfDot,
	const float* vecLabels,
	float *result,
	const int mainVecIdx,
	const int nrRows,
	const float gamma, 
	const int align){

		//sh_data size = SliceSize*ThreadsPerRow*sizeof(float)
		//float* sh_cache = (float*)sh_data;
		__shared__  float sh_cache[ThreadPerRow*SliceSize];

		__shared__ int shMainVecIdx;
		__shared__ float shMainSelfDot;
		__shared__ float shLabel;
		__shared__ float shGamma;

		if(threadIdx.x==0)
		{
			shMainVecIdx=mainVecIdx;
			shMainSelfDot = selfDot[shMainVecIdx];
			shLabel = vecLabels[shMainVecIdx];
			shGamma=gamma;
		}

		int tx = threadIdx.x;
		int txm = tx %  ThreadPerRow;
		int thIdx = (blockIdx.x*blockDim.x+threadIdx.x);

		//map group of thread to row, in this case 4 threads are mapped to one row
		int row =  thIdx>> LOG_THREADS; // 

		if (row < nrRows){
			float sub = 0.0;
			int maxRow = (int)ceil(vecLengths[row]/(float)ThreadPerRow);
			int col=-1;
			float value =0;
			int ind=0;

			for(int i=0; i < maxRow; i++){
				ind = i*align+sliceStart[blockIdx.x]+tx;
				col     = vecCols[ind];
				value = vecVals[ind];
				sub += value * tex1Dfetch(mainVecTexRef, col);
			}

			sh_cache[tx] = sub;
			__syncthreads();

			volatile float *shMem = sh_cache;
		

			for(int s=ThreadPerRow/2; s>0; s>>=1) //s/=2
			{
				if(txm < s){
					shMem[tx] += shMem[tx+s];
				}
			}

			if(txm == 0 ){
					result[row]=vecLabels[row]*shLabel*expf(-shGamma*(selfDot[row]+shMainSelfDot-2*sh_cache[tx]));
				}

	
			//for 4 thread per row
			//if(txm < 2){
			//	shMem[tx]+=shMem[tx+2];
			//	shMem[tx] += shMem[tx+1];
			//if(txm < 1){
			//	shMem[tx] += shMem[tx+1];
			//	if(txm == 0 ){
			//		result[row]=vecLabels[row]*shLabel*expf(-shGamma*(selfDot[row]+shMainSelfDot-2*sh_cache[tx]));
			//	}
			//}
		}//if row<nrRows 
}//end func



//Use sliced Ellpack format for computing rbf kernel
//vecVals - vectors values in Sliced Ellpack,
//vecCols - array containning column indexes for non zero elements
//vecLengths  - number of non zero elements in row
//sliceStart   - determine where particular slice starts and ends
//selfDot    - precomputed self dot product
//result  - for final result
//mainVecIdx - index of main vector
//nrows   - number of rows
//ali	  - align
extern "C" __global__ void rbfSlicedEllpackKernel_shared(const float *vecVals,
	const int *vecCols,
	const int *vecLengths, 
	const int * sliceStart, 
	const float* selfDot,
	const float* vecLabels,
	float *result,
	const int mainVecIdx,
	const int nrRows,
	const float gamma, 
	const int align){

		//sh_data size = SliceSize*ThreadsPerRow*sizeof(float)
		//float* sh_cache = (float*)sh_data;
		__shared__  float sh_cache[ThreadPerRow*SliceSize];

		__shared__ int shMainVecIdx;
		__shared__ float shMainSelfDot;
		__shared__ float shLabel;
		__shared__ float shGamma;

		if(threadIdx.x==0)
		{
			shMainVecIdx=mainVecIdx;
			shMainSelfDot = selfDot[shMainVecIdx];
			shLabel = vecLabels[shMainVecIdx];
			shGamma=gamma;
		}

		__shared__ float shMainVecAR[VECDIM];
		volatile float *shMainVec =shMainVecAR;

		for(int k=threadIdx.x;k<VECDIM;k+=blockDim.x)
			shMainVec[k]=tex1Dfetch(mainVecTexRef,k);

		__syncthreads();

		int tx = threadIdx.x;
		int txm = tx % 4; //tx% ThreadPerRow
		int thIdx = (blockIdx.x*blockDim.x+threadIdx.x);

		//map group of thread to row, in this case 4 threads are mapped to one row
		int row =  thIdx>> 2; // 

		if (row < nrRows){
			float sub = 0.0;
			int maxRow = (int)ceil(vecLengths[row]/(float)ThreadPerRow);
			int labelProd = vecLabels[row]*shLabel;
			int ind = -1;
			int col =-1;
			float value=0;

			for(int i=0; i < maxRow; i++){
				ind = i*align+sliceStart[blockIdx.x]+tx;

				col     = vecCols[ind];
				value = vecVals[ind];

				sub += value * shMainVec[col];
			}

			sh_cache[tx] = sub;
			__syncthreads();

			volatile float *shMem = sh_cache;
			//for 4 thread per row

			if(txm < 2){
				shMem[tx]+=shMem[tx+2];
				shMem[tx] += shMem[tx+1];

				if(txm == 0 ){
					//result[row]=vecLabels[row]*shLabel*expf(-0.5*(selfDot[row]+shMainSelfDot-2*sh_cache[tx]));
					value = labelProd*expf(-shGamma*(selfDot[row]+shMainSelfDot-2*sh_cache[tx]));
					//value = floorf(value*1000+0.5)/1000;
					result[row]=value;
					//result[row]=vecLabels[row]*shLabel*expf(-GammaDev*(selfDot[row]+shMainSelfDot-2*sh_cache[tx]));
				}
			}


		}//if row<nrRows 



}//end func


//TODO: impelmentacja rbfSlEll_ILP

//Use sliced Ellpack format for computing rbf kernel
//vecVals - vectors values in Sliced Ellpack,
//vecCols - array containning column indexes for non zero elements
//vecLengths  - number of non zero elements in row
//sliceStart   - determine where particular slice starts and ends
//selfDot    - precomputed self dot product
//result  - for final result
//mainVecIdx - index of main vector
//nrows   - number of rows
//ali	  - align
extern "C" __global__ void rbfSERTILP(const float *vecVals,
	const int *vecCols,
	const int *vecLengths, 
	const int * sliceStart, 
	const float* selfDot,
	const float* vecLabels,
	float *result,
	const int mainVecIdx,
	const int nrRows,
	const float gamma, 
	const int align){

		//sh_data size = SliceSize*ThreadsPerRow*sizeof(float)
		//float* sh_cache = (float*)sh_data;
		__shared__  float shDot[ThreadPerRow*SliceSize];

		//define ROWS_B BLOCK_SIZE/THREADS_ROW
		#define ROWS_B SliceSize
		//__shared__ int shMaxRows[ROWS_B];

		__shared__ int shMainVecIdx;
		__shared__ int shSliceStart;
		__shared__ float shMainSelfDot;
		__shared__ float shLabel;
		__shared__ float shGamma;

		if(threadIdx.x==0)
		{
			shMainVecIdx=mainVecIdx;
			shMainSelfDot = selfDot[shMainVecIdx];
			shLabel = vecLabels[shMainVecIdx];
			shGamma=gamma;
			shSliceStart=sliceStart[blockIdx.x];
		}
		__syncthreads();

		//int tid = threadIdx.x;

		int idxT = threadIdx.x % ThreadPerRow; //thred number in Thread Goup
		int idxR = threadIdx.x/ThreadPerRow; //row index mapped into block region

		//int thIdx = (blockIdx.x*blockDim.x+threadIdx.x);
		//map group of thread to row, in this case 4 threads are mapped to one row
		int row =  (blockIdx.x*blockDim.x+threadIdx.x)>> LOG_THREADS; 

		if (row < nrRows){

			
			//if(threadIdx.x < ROWS_B){
			//	unsigned int row2=blockIdx.x* ROWS_B+threadIdx.x;
			//	if(row2<nrRows){
			//		shMaxRows[threadIdx.x] = vecLengths[row2];
			//	}
			//}
			//__syncthreads();			
			//int maxRow = shMaxRows[idxR];
			
			int maxRow = vecLengths[row];
			//int maxRow = (int)ceil(vecLengths[row]/(float)(ThreadPerRow*PREFETCH_SIZE) );

			float val[PREFETCH_SIZE];
			int col[PREFETCH_SIZE];
			float dot[PREFETCH_SIZE]={0};

			unsigned int j=0;
			unsigned int arIdx=0;
			for(int i=0; i < maxRow; i++){
				
				#pragma unroll
				for( j=0; j<PREFETCH_SIZE;j++)	{
					//arIdx = (i*PREFETCH_SIZE+j )*align+sliceStart[blockIdx.x]+threadIdx.x;
					arIdx = (i*PREFETCH_SIZE+j )*align+shSliceStart+threadIdx.x;
					col[j] = vecCols[arIdx];
					val[j] = vecVals[arIdx];
				}

				#pragma unroll
				for( j=0; j<PREFETCH_SIZE;j++){
					dot[j] +=val[j]*tex1Dfetch(mainVecTexRef,col[j]); // val[j]* tex1Dfetch(mainVecTexRef,col[j]);
				}
			}

			#pragma unroll
			for( j=1; j<PREFETCH_SIZE;j++){
				dot[0]+=dot[j];	
			}



		shDot[idxT*ROWS_B+idxR]=dot[0];
		__syncthreads();		

		volatile float *shDotv = shDot;
		//reduction to some level
		for( j=blockDim.x/2; j>=ROWS_B; j>>=1) //s/=2
		{
			if(threadIdx.x<j){
				shDotv[threadIdx.x]+=shDotv[threadIdx.x+j];
			}
			__syncthreads();
		}
			
		if(threadIdx.x<ROWS_B){
			//results[row2]=row2;			
			unsigned int row2=blockIdx.x* ROWS_B+threadIdx.x;
			if(row2<nrRows){
			//result[row2]= shDotv[threadIdx.x];
				result[row2]=vecLabels[row2]*shLabel*expf(-shGamma*(selfDot[row2]+shMainSelfDot-2*shDot[threadIdx.x]));
			}
		}

	}//if row<nrRows 
}//end func








/****** nChi2 kernels *******************/
//Use sliced Ellpack format for computing normalized Chi2 kernel, vectors should be histograms
// and normalized according to l1 norm
// K(x,y)= Sum( (xi*yi)/(xi+yi))
//
//vecVals - vectors values in Sliced Ellpack,
//vecCols - array containning column indexes for non zero elements
//vecLengths  - number of non zero elements in row
//sliceStart   - determine where particular slice starts and ends
//result  - for final result
//mainVecIdx - index of main vector
//nrows   - number of rows
//ali	  - align
extern "C" __global__ void nChi2SlEllKernel(const float *vecVals,
	const int *vecCols,
	const int *vecLengths, 
	const int * sliceStart, 
	const float* vecLabels,
	float *result,
	const int mainVecIdx,
	const int nrRows,
	const int align){

		//sh_data size = SliceSize*ThreadsPerRow*sizeof(float)
		//float* sh_cache = (float*)sh_data;
		__shared__  float sh_cache[ThreadPerRow*SliceSize];

		__shared__ int shMainVecIdx;
		__shared__ float shLabel;

		if(threadIdx.x==0)
		{
			shMainVecIdx=mainVecIdx;
			shLabel = vecLabels[shMainVecIdx];
		}

		int tx = threadIdx.x;
		int txm = tx % 4; //tx% ThreadPerRow
		int thIdx = (blockIdx.x*blockDim.x+threadIdx.x);

		//map group of thread to row, in this case 4 threads are mapped to one row
		int row =  thIdx>> 2; // 

		if (row < nrRows){
			float sub = 0.0;
			int maxRow = (int)ceil(vecLengths[row]/(float)ThreadPerRow);
			int col=-1;
			float val1 =0;
			float val2 =0;
			int ind=0;

			for(int i=0; i < maxRow; i++){
				ind = i*align+sliceStart[blockIdx.x]+tx;

				col     = vecCols[ind];
				val1 = vecVals[ind];
				val2 = tex1Dfetch(mainVecTexRef, col);
				sub += (val1*val2)/(val1+val2+FLT_MIN);
			}

			sh_cache[tx] = sub;
			__syncthreads();

			volatile float *shMem = sh_cache;
			//for 4 thread per row

			if(txm < 2){
				shMem[tx]+=shMem[tx+2];
				shMem[tx] += shMem[tx+1];

				if(txm == 0 ){
					result[row]=vecLabels[row]*shLabel*sh_cache[tx];
				}
			}
		}//if row<nrRows  
}//end func



/************* ExpChi2 kernels *******************/

//Use sliced Ellpack format for computing ExpChi2 kernel matrix kolumn
// K(x,y)=exp( -gamma* Sum( (xi-yi)^2/(xi+yi)) =exp(-gamma (sum xi +sum yi -4*sum( (xi*yi)/(xi+yi)) ) )
//vecVals - vectors values in Sliced Ellpack,
//vecCols - array containning column indexes for non zero elements
//vecLengths  - number of non zero elements in row
//sliceStart   - determine where particular slice starts and ends
//selfSum    - precomputed sum of each row
//result  - for final result
//mainVecIdx - index of main vector
//nrows   - number of rows
//ali	  - align
extern "C" __global__ void expChi2SlEllKernel(const float *vecVals,
	const int *vecCols,
	const int *vecLengths, 
	const int * sliceStart, 
	const float* selfSum,
	const float* vecLabels,
	float *result,
	const int mainVecIdx,
	const int nrRows,
	const float gamma, 
	const int align){

		__shared__  float sh_cache[ThreadPerRow*SliceSize];

		__shared__ int shMainVecIdx;
		__shared__ float shMainSelfSum;
		__shared__ float shLabel;
		__shared__ float shGamma;

		if(threadIdx.x==0)
		{
			shMainVecIdx=mainVecIdx;
			shMainSelfSum = selfSum[shMainVecIdx];
			shLabel = vecLabels[shMainVecIdx];
			shGamma=gamma;
		}

		int tx = threadIdx.x;
		int txm = tx % 4; //tx% ThreadPerRow
		int thIdx = (blockIdx.x*blockDim.x+threadIdx.x);

		//map group of thread to row, in this case 4 threads are mapped to one row
		int row =  thIdx>> 2; // 

		if (row < nrRows){
			float sub = 0.0;
			int maxRow = (int)ceil(vecLengths[row]/(float)ThreadPerRow);
			int col=-1;
			float val1 =0;
			float val2 =0;
			int ind=0;

			for(int i=0; i < maxRow; i++){
				ind = i*align+sliceStart[blockIdx.x]+tx;

				col     = vecCols[ind];
				val1 = vecVals[ind];
				val2 = tex1Dfetch(mainVecTexRef, col);
				sub += (val1*val2)/(val1+val2+FLT_MIN);
			}

			sh_cache[tx] = sub;
			__syncthreads();

			volatile float *shMem = sh_cache;
			//for 4 thread per row

			if(txm < 2){
				shMem[tx]+=shMem[tx+2];
				shMem[tx] += shMem[tx+1];

				if(txm == 0 ){
					result[row]=vecLabels[row]*shLabel*expf(-shGamma*(selfSum[row]+shMainSelfSum-4*sh_cache[tx]));
				}
			}


		}//if row<nrRows 


}//end func



/************************* HELPER FUNCTIONS ****************************/

extern "C" __global__ void makeDenseVectorSlicedEllRT(const float *vecVals,
	const int *vecCols,
	const int *vecLengths, 
	const int * sliceStart, 
	float *mainVector,
	const int mainVecIdx,
	const int nrRows,
	const int vecDim,
	const int align){


		__shared__ int shMaxNNZ;
		__shared__ int shSliceNr;
		__shared__ int shRowInSlice;

		if(threadIdx.x==0)
		{
			shMaxNNZ =	vecLengths[mainVecIdx];
			//in which slice main vector is?
			shSliceNr = mainVecIdx/SliceSize;
			shRowInSlice = mainVecIdx% SliceSize;
		}

		int thIdx = (blockIdx.x*blockDim.x+threadIdx.x);
		//int tmx = threadIdx.x % ThreadPerRow;	

		if(thIdx < vecDim)
		{
			//set all vector values to zero
			mainVector[thIdx]=0.0;

			if(thIdx <shMaxNNZ){
				int threadNr = thIdx%ThreadPerRow;
				int rowSlice= thIdx/ThreadPerRow;

				//int	ind = sliceStart[shSliceNr]+shStartRow+tmx;

				int idx = sliceStart[shSliceNr] + align * rowSlice + shRowInSlice * ThreadPerRow + threadNr;

				int col     = vecCols[idx];
				float value = vecVals[idx];
				mainVector[col]=value;
			}


		}//end if

}//end func
