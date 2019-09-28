using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Assertions;
using Vector3 = UnityEngine.Vector3;

[RequireComponent(typeof(MeshFilter))]
public class MeshGenerator : MonoBehaviour
{
    private MeshFilter _filter;
    private Mesh _mesh;

    /// <summary>
    /// Executed by Unity upon object initialization. <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Awake()
    {
        _filter = GetComponent<MeshFilter>();
        _mesh = _filter.mesh = new Mesh();
        _mesh.MarkDynamic();
    }

    private readonly List<Vector3> _cubeVertices = new List<Vector3>
    {
        new Vector3(0, 0, 0), // 0
        new Vector3(0, 1, 0), // 1
        new Vector3(1, 1, 0), // 2
        new Vector3(1, 0, 0), // 3
        new Vector3(0, 0, 1), // 4
        new Vector3(0, 1, 1), // 5
        new Vector3(1, 1, 1), // 6
        new Vector3(1, 0, 1), // 7
    };

    private readonly int[][] _cubeEdges = new int[][]
    {
        new int[] {0, 1},
        new int[] {1, 2},
        new int[] {2, 3},
        new int[] {3, 0},
        new int[] {4, 5},
        new int[] {5, 6},
        new int[] {6, 7},
        new int[] {7, 4},
        new int[] {0, 4},
        new int[] {1, 5},
        new int[] {2, 6},
        new int[] {3, 7},
    };

    /// <summary>
    /// Executed by Unity on every first frame <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Update()
    {
        Func<Vector3, double> f = v =>
        {
            double result = 0;
            result += 1.0 / (v - new Vector3(0, 0, 0)).sqrMagnitude;
            result += 1.0 / (v - new Vector3(Mathf.Sin(Time.time) * 3, 0, 0)).sqrMagnitude;
            return result - 1.2;
        };

        const float MAXC = 4;
        const float MINX = -MAXC, MAXX = MAXC;
        const float MINY = -MAXC, MAXY = MAXC;
        const float MINZ = -MAXC, MAXZ = MAXC;
        const int STEPS = 25;

        List<Vector3> triangleVertices = new List<Vector3>();
        List<int> triangles = new List<int>();

        Vector3 cubeSize = new Vector3(
            (MAXX - MINX) / STEPS,
            (MAXY - MINY) / STEPS,
            (MAXZ - MINZ) / STEPS
        );

        Vector3 pos0;
        Vector3[] vertices = new Vector3[_cubeVertices.Count];
        double[] verticesVal = new double[_cubeVertices.Count];
        Vector3[] edgesPos = new Vector3[_cubeEdges.Length];

        for (int zi = 0; zi < STEPS; zi++)
        for (int yi = 0; yi < STEPS; yi++)
        for (int xi = 0; xi < STEPS; xi++)
        {
            pos0.x = MINX + xi * (MAXX - MINX) / STEPS;
            pos0.y = MINY + yi * (MAXX - MINX) / STEPS;
            pos0.z = MINZ + zi * (MAXX - MINX) / STEPS;

            int verticesMsk = 0;
            for (int i = 0; i < _cubeVertices.Count; i++)
            {
                vertices[i] = Vector3.Scale(_cubeVertices[i], cubeSize) + pos0;
                verticesVal[i] = f(vertices[i]);
                if (verticesVal[i] > 0)
                    verticesMsk |= 1 << i;
            }

            if (MarchingCubes.Tables.CaseToTrianglesCount[verticesMsk] == 0)
            {
                continue;
            }

            for (int i = 0; i < _cubeEdges.Length; i++)
            {
                Vector3 a = vertices[_cubeEdges[i][0]], b = vertices[_cubeEdges[i][1]];
                double av = verticesVal[_cubeEdges[i][0]], bv = verticesVal[_cubeEdges[i][1]];
                if (av * bv <= 0)
                {
                    double t = -av / (bv - av);
                    t = Math.Max(0, Math.Min(1, t));
                    edgesPos[i] = a + (float) t * (b - a);
                }
            }

            for (int i = 0; i < MarchingCubes.Tables.CaseToTrianglesCount[verticesMsk]; i++)
            {
                int3 edgeIds = MarchingCubes.Tables.CaseToVertices[verticesMsk][i];
                triangleVertices.Add(edgesPos[edgeIds.x]);
                triangleVertices.Add(edgesPos[edgeIds.y]);
                triangleVertices.Add(edgesPos[edgeIds.z]);
                triangles.Add(triangleVertices.Count - 3);
                triangles.Add(triangleVertices.Count - 2);
                triangles.Add(triangleVertices.Count - 1);
            }
        }

        // Here unity automatically assumes that vertices are points and hence will be represented as (x, y, z, 1) in homogenous coordinates
        _mesh.Clear(); // To avoid "the supplied vertex array has less vertices than are referenced by the triangles array" error.
        _mesh.SetVertices(triangleVertices);
        _mesh.SetTriangles(triangles, 0);
        _mesh.RecalculateNormals();

        // Upload mesh data to the GPU
        _mesh.UploadMeshData(false);
    }
}