﻿/*
author: Krzysztof Sopyla
mail: krzysztofsopyla@gmail.com
License: MIT
web page: http://wmii.uwm.edu.pl/~ksopyla/projects/svm-net-with-cuda-kmlib/
*/
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using KMLib.Helpers;

namespace KMLib.GPU.GPUEvaluators
{


    /// <summary>
    /// Class for prediction with Exp Chi^2 kernel in Sliced-Ellpack format 
    /// </summary>
    public class CuExpChiSlEllEvaluator : CuEvaluator
    {
        private GASS.CUDA.Types.CUdeviceptr valsPtr;
        private GASS.CUDA.Types.CUdeviceptr idxPtr;
        private GASS.CUDA.Types.CUdeviceptr vecLengthPtr;
        private GASS.CUDA.Types.CUdeviceptr sliceStartPtr;
        private GASS.CUDA.Types.CUdeviceptr selfSumPtr;

        
        private float gamma;

        /// <summary>
        /// how many threads are assigned for row
        /// </summary>
        private int threadsPerRow;

        /// <summary>
        /// how big the matrix slice is
        /// </summary>
        private int sliceSize;
        private int align;
        private int vectorSelfSumParamOffset;




        public CuExpChiSlEllEvaluator(float gamma)
        {
            this.gamma = gamma;
            cudaEvaluatorKernelName = "expChi2SliceEllpackEvaluator";
            cudaModuleName = "KernelsSlicedEllpack.cubin";

            threadsPerRow = 4;
            sliceSize = 64;

        }

        protected override void SetCudaEvalFuncParamsForVector(SparseVec vec)
        {
            cuda.SetParameter(cuFuncEval, vectorSelfSumParamOffset, vec.Values.Sum());
        }

        protected override void SetCudaEvalFunctionParams()
        {


            cuda.SetFunctionBlockShape(cuFuncEval, evalThreads, 1, 1);

            int offset = 0;
            cuda.SetParameter(cuFuncEval, offset, valsPtr.Pointer);
            offset += IntPtr.Size;
            cuda.SetParameter(cuFuncEval, offset, idxPtr.Pointer);
            offset += IntPtr.Size;

            cuda.SetParameter(cuFuncEval, offset, vecLengthPtr.Pointer);
            offset += IntPtr.Size;

            cuda.SetParameter(cuFuncEval, offset, sliceStartPtr.Pointer);
            offset += IntPtr.Size;



            cuda.SetParameter(cuFuncEval, offset, selfSumPtr.Pointer);
            offset += IntPtr.Size;


            cuda.SetParameter(cuFuncEval, offset, alphasPtr.Pointer);
            offset += IntPtr.Size;

            cuda.SetParameter(cuFuncEval, offset, labelsPtr.Pointer);
            offset += IntPtr.Size;

            kernelResultParamOffset = offset;
            cuda.SetParameter(cuFuncEval, offset, evalOutputCuPtr[0].Pointer);
            offset += IntPtr.Size;

            cuda.SetParameter(cuFuncEval, offset, (uint)sizeSV);
            offset += sizeof(int);

            cuda.SetParameter(cuFuncEval, offset, (uint)align);
            offset += sizeof(int);

            vectorSelfSumParamOffset = offset;
            cuda.SetParameter(cuFuncEval, offset, 0);
            offset += sizeof(int);

            cuda.SetParameter(cuFuncEval, offset, gamma);
            offset += sizeof(float);

            texSelParamOffset = offset;
            cuda.SetParameter(cuFuncEval, offset, 1);
            offset += sizeof(int);

            cuda.SetParameterSize(cuFuncEval, (uint)offset);
        }
         

       

        public override void Init()
        {
            base.Init();

            SetCudaDataForFormat();

             SetCudaEvalFunctionParams();
        }

        private void SetCudaDataForFormat()
        {


            evalThreads = threadsPerRow * sliceSize;
            int N = sizeSV;
            evalBlocks = (int)Math.Ceiling(1.0 * N * threadsPerRow / evalThreads);

            align = (int)Math.Ceiling(1.0 * sliceSize * threadsPerRow / 64) * 64;


            float[] vecVals;
            int[] vecColIdx;
            int[] vecLenght;
            int[] sliceStart;

            CudaHelpers.TransformToSlicedEllpack(out vecVals, out vecColIdx, out sliceStart, out vecLenght, TrainedModel.SupportElements, threadsPerRow, sliceSize);

            float[] selfSum = TrainedModel.SupportElements.AsParallel().Select(c => c.Values.Sum()).ToArray();

 
            //copy data to device, set cuda function parameters
            //copy data to device, set cuda function parameters
            valsPtr = cuda.CopyHostToDevice(vecVals);
            idxPtr = cuda.CopyHostToDevice(vecColIdx);
            vecLengthPtr = cuda.CopyHostToDevice(vecLenght);
            sliceStartPtr = cuda.CopyHostToDevice(sliceStart);
            
            selfSumPtr = cuda.CopyHostToDevice(selfSum);

            

        }

        public void Dispose()
        {
            if (cuda != null)
            {

                cuda.Free(selfSumPtr);
                selfSumPtr.Pointer = IntPtr.Zero;

                DisposeResourses();

                cuda.UnloadModule(cuModule);
                base.Dispose();
                cuda.Dispose();
                cuda = null;
            }
        }

    }
}