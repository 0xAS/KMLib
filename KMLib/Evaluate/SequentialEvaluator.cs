﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using dnAnalytics.LinearAlgebra;
using System.Threading.Tasks;

namespace KMLib.Evaluate
{
    /// <summary>
    /// represents sequential evaluation(prediction) for new unseen vector elements,
    /// </summary>
    public class SequentialEvaluator: EvaluatorBase<SparseVector>
    {
        
        #region IEvaluator<SparseVector> Members

        public override float[] Predict(SparseVector[] elements)
        {
            float[] predictions = new float[elements.Length];

            Parallel.For(0, elements.Length, i =>
            {

                predictions[i] = Predict(elements[i]);
            });

            return predictions;
        }

        public override float Predict(SparseVector element)
        {
            float sum = 0;

            int index = -1;

            for (int k = 0; k < TrainedModel.SupportElementsIndexes.Length; k++)
            {
                index = TrainedModel.SupportElementsIndexes[k];
                sum += TrainedModel.Alpha[index] * TrainningProblem.Labels[index] *
                                    Kernel.Product(TrainningProblem.Elements[index], element);
            }

            sum -= TrainedModel.Rho;

            float ret = sum > 0 ? 1 : -1;
            return ret;
        }

        #endregion

       
    }
}
