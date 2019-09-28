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

    private readonly double EPS = 1e-6;
    
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

        const float MAXC = 8;
        const float MINX = -MAXC, MAXX = MAXC;
        const float MINY = -MAXC, MAXY = MAXC;
        const float MINZ = -MAXC, MAXZ = MAXC;
        const int STEPS = 50;

        List<Vector3> triangleVertices = new List<Vector3>();
        List<int> triangles = new List<int>();

        Vector3 cubeSize = new Vector3(
            (MAXX - MINX) / STEPS,
            (MAXY - MINY) / STEPS,
            (MAXZ - MINZ) / STEPS
        );
        for (int zi = 0; zi < STEPS; zi++)
        for (int yi = 0; yi < STEPS; yi++)
        for (int xi = 0; xi < STEPS; xi++)
        {
            Vector3 pos0 = new Vector3(
                MINX + xi * (MAXX - MINX) / STEPS,
                MINY + yi * (MAXX - MINX) / STEPS,
                MINZ + zi * (MAXX - MINX) / STEPS
            );
            Vector3[] vertices = _cubeVertices.Select(v => Vector3.Scale(v, cubeSize) + pos0).ToArray();
            double[] verticesVal = vertices.Select(v => f(v)).ToArray();
            int verticesMsk = 0;
            for (int i = 0; i < vertices.Length; i++)
                if (verticesVal[i] > 0)
                    verticesMsk |= 1 << i;
            if (MarchingCubes.Tables.CaseToTrianglesCount[verticesMsk] == 0)
            {
                continue;
            }

            Vector3?[] edgesPos = _cubeEdges.Select(edgeEnds =>
            {
                Vector3 a = vertices[edgeEnds[0]], b = vertices[edgeEnds[1]];
                double av = verticesVal[edgeEnds[0]], bv = verticesVal[edgeEnds[1]];
                double t = -av / (bv - av);
                if (-EPS <= t && t <= 1.0 + EPS) // NaNs are ignored
                {
                    t = Math.Max(0, Math.Min(1, t));
                    return (Vector3?)(a + (float)t * (b - a));
                }
                else
                {
                    return null;
                }
            }).ToArray();
            
            for (int i = 0; i < MarchingCubes.Tables.CaseToTrianglesCount[verticesMsk]; i++)
            {
                int3 edgeIds = MarchingCubes.Tables.CaseToVertices[verticesMsk][i];
                if (edgesPos[edgeIds.x] == null || edgesPos[edgeIds.y] == null || edgesPos[edgeIds.z] == null)
                {
                    throw new InvalidOperationException("There is no vertex on an edge");
                }
                triangleVertices.Add((Vector3)edgesPos[edgeIds.x]);
                triangleVertices.Add((Vector3)edgesPos[edgeIds.y]);
                triangleVertices.Add((Vector3)edgesPos[edgeIds.z]);
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