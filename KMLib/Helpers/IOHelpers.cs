﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using dnaLA = dnAnalytics.LinearAlgebra;
using System.Globalization;

namespace KMLib.Helpers
{
    public class IOHelper
    {
        /// <summary>
        /// Reads vectos from file.
        /// File format like in LIbSVM
        /// label index:value index2:value .....
        /// -1        4:0.5       10:0.9 ....
        /// </summary>
        /// <param name="fileName">Data set file name</param>
        /// <returns></returns>
        //public static Problem<Vector> ReadVectorsFromFile(string fileName)
        //{



        //    List<float> labels = new List<float>();

        //    List<Vector> vectors = new List<Vector>();

        //    using (FileStream fileStream = File.OpenRead(fileName))
        //    {
        //        using (StreamReader input = new StreamReader(fileStream))
        //        {

        //            int max_index = 0;

        //            while (input.Peek() > -1)
        //            {
        //                string[] parts = input.ReadLine().Trim().Split();

        //                //label
        //                labels.Add(float.Parse(parts[0]));

        //                //other parts with index and value
        //                int m = parts.Length - 1;


        //                List<Vector.Node> nodes = new List<Vector.Node>();


        //                int index = 0;
        //                float value;
        //                for (int j = 0; j < m; j++)
        //                {

        //                    string[] nodeParts = parts[j + 1].Split(':');
        //                    index = int.Parse(nodeParts[0]);
        //                    value = float.Parse(nodeParts[1], System.Globalization.CultureInfo.InvariantCulture);

        //                    nodes.Add(new Vector.Node(index, (float)value));
        //                    // v[index] = value;

        //                }

        //                if (m > 0)
        //                {
        //                    max_index = Math.Max(max_index, index);
        //                }
        //                vectors.Add(new Vector(nodes));
        //            }

        //            //assing max index as  vector Dimension,
        //            //not always true for different data sets
        //            for (int i = 0; i < vectors.Count; i++)
        //            {
        //                vectors[i].Dimension = max_index;
        //            }

        //        }
        //    }
            
        //    //Problem<Vector> vectorProblem = new Problem<Vector>(vectors.ToArray(),labels.ToArray());
            
            
        //    //vectorProblem.Elements = vectors.ToArray();
        //    //vectorProblem.ElementsCount = vectors.Count;
        //    //vectorProblem.Labels = labels.ToArray();
            
        //    //return vectorProblem;
            
        //    return new Problem<Vector>(vectors.ToArray(), labels.ToArray());
        //}


        /// <summary>
        /// Reads vectos from file. Creates Vectors from dnAnalitycs library.
        /// File format like in LIbSVM
        /// label index:value index2:value .....
        /// -1        4:0.5       10:0.9 ....
        /// </summary>
        /// <param name="fileName">Data set file name</param>
        /// <returns></returns>
        public static Problem<dnaLA.SparseVector> ReadDNAVectorsFromFile(string fileName,int numberOfFeatures) 
        {
            //initial list capacity 8KB, its heuristic
            int listCapacity = 1 << 13;
            
            //list of labels
            List<float> labels = new List<float>(listCapacity);

            //list of array, each array symbolize vector
            List<KeyValuePair<int, double>[]> vectors = new List<KeyValuePair<int, double>[]>(listCapacity);
            //new List<List<KeyValuePair<int, double>>>();

            //vector parts (index and value) separator
            char[] vecPartsSeparator = new char[]{' '};
            //separator between index and value in one part
            char[] idxValSeparator = new char[] { ':' };
            int max_index = 0;

            List<KeyValuePair<int, double>> vec = new List<KeyValuePair<int, double>>(32);

            using (FileStream fileStream = File.OpenRead(fileName))
            {
                using (StreamReader input = new StreamReader(fileStream))
                {
                    

                    //todo: string split function to many memory allocation, http://msdn.microsoft.com/en-us/library/b873y76a.aspx
                    while (input.Peek() > -1)
                    {
                        int indexSeparatorPosition = -1;
                        string inputLine = input.ReadLine().Trim();

                        int index = 0;

                        float value=0;
                        
                        
                        
                       /*
                        string[] parts =inputLine.Split(vecPartsSeparator,StringSplitOptions.RemoveEmptyEntries);

                        //label
                        labels.Add(float.Parse(parts[0],CultureInfo.InvariantCulture));

                        //other parts with index and value
                        int m = parts.Length - 1;

                        //list of index and value for one vector
                        List<KeyValuePair<int, double>> vec = new List<KeyValuePair<int, double>>(m);
                        
                       
                        //extract index and value
                        for (int j = 0; j < m; j++)
                        {

                            //string[] nodeParts = parts[j + 1].Split(idxValSeparator);
                            //index = int.Parse(nodeParts[0]);
                            //value = float.Parse(nodeParts[1], System.Globalization.CultureInfo.InvariantCulture);
                            
                            //it is more memory eficcient than above version with split
                            indexSeparatorPosition = parts[j + 1].IndexOf(idxValSeparator[0]);
                            index = int.Parse(parts[j+1].Substring(0,indexSeparatorPosition) );
                            value = float.Parse(parts[j+1].Substring(indexSeparatorPosition+1));

                            vec.Add(new KeyValuePair<int, double>(index, value));
                            // v[index] = value;

                        }
                        */


                        //add one space to the end of line, needed for parsing
                        string oneLine = new StringBuilder(inputLine).Append(" ").ToString();

                       
                        
                        int partBegin = -1, partEnd = -1;

                        partBegin = oneLine.IndexOf(vecPartsSeparator[0]);
                        //from begining to first space is label
                        labels.Add(float.Parse(oneLine.Substring(0, partBegin)));

                        index = 0;

                        value=0;
                        partEnd = oneLine.IndexOf(vecPartsSeparator[0], partBegin + 1);

                        while (partEnd > 0)
                        {

                            indexSeparatorPosition = oneLine.IndexOf(idxValSeparator[0], partBegin);
                            index = int.Parse(oneLine.Substring(partBegin + 1, indexSeparatorPosition - (partBegin+1)));
                            value = float.Parse(oneLine.Substring(indexSeparatorPosition + 1, partEnd - (indexSeparatorPosition+1)));


                            vec.Add(new KeyValuePair<int, double>(index, value));
                            partBegin = partEnd;
                            partEnd = oneLine.IndexOf(vecPartsSeparator[0], partBegin + 1);

                        }


                        if (vec.Count> 0)
                        {
                            max_index = Math.Max(max_index, index);
                        }


                        //we implictie set numberOfFeatures if max_index is less then numberOfFeatures
                        if (max_index < numberOfFeatures)
                            max_index = numberOfFeatures;


                        vectors.Add(vec.ToArray());

                        //clear vector parts
                        vec.Clear();
                    }//end while
                }
            }

            long doubleCount = 0;
            long valCount = 0;
            //list of Vectors, currently use SparseVector implementation from dnAnalitycs
            List<dnaLA.SparseVector> dnaVectors = new List<dnaLA.SparseVector>(vectors.Count);
            //assing max index as  vector Dimension,
            //not always true for different data sets
            for (int i = 0; i < vectors.Count; i++)
            {
                dnaLA.SparseVector oneVec = new dnaLA.SparseVector(max_index+1);
                
                for (int j = 0; j < vectors[i].Length; j++)
                {
                    int index = vectors[i][j].Key;
                    double val = vectors[i][j].Value;
                    oneVec[index] = val;
                }
                doubleCount += oneVec.mIndices.LongLength;
                doubleCount += oneVec.mValues.LongLength;
                valCount += oneVec.mValueCount;

                dnaVectors.Add(oneVec);

            }



            return new Problem<dnaLA.SparseVector>(dnaVectors.ToArray(), labels.ToArray());
        }
    }
}
