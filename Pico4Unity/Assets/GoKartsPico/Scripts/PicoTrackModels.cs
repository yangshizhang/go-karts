using System;
using System.Collections.Generic;
using UnityEngine;

namespace GoKartsPico
{
    public enum PicoLapMode
    {
        PointToPoint,
        ClosedCircuit
    }

    public enum PicoLineSignal
    {
        Accelerate,
        Braking
    }

    [Serializable]
    public struct PicoTrackPoint
    {
        public double latitude;
        public double longitude;
        public double altitude;
        public float speed;
        public long unixMilliseconds;
        public PicoLineSignal signal;
    }

    [Serializable]
    public class PicoTrackDefinition
    {
        public string id = Guid.NewGuid().ToString("N");
        public string name = "未命名赛道";
        public PicoLapMode lapMode = PicoLapMode.ClosedCircuit;
        public List<PicoTrackPoint> boundary = new List<PicoTrackPoint>();
        public List<PicoTrackPoint> racingLine = new List<PicoTrackPoint>();
        public PicoTrackPoint startPoint;
        public PicoTrackPoint finishPoint;
        public long updatedUnixMilliseconds;
    }

    [Serializable]
    public class PicoTrackCollection
    {
        public List<PicoTrackDefinition> tracks = new List<PicoTrackDefinition>();
    }
}
