using System;
using System.Collections.Generic;
using UnityEngine;

namespace GoKartsPico
{
    public sealed class PicoRacingLineRenderer : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private PicoTrackStore trackStore;
        [SerializeField] private Transform xrOrigin;
        [SerializeField] private Material lineMaterialTemplate;
        [SerializeField] private Material markerMaterialTemplate;

        [Header("MR Line")]
        [SerializeField] private float lineWidthMeters = 0.42f;
        [SerializeField] private float lineHeightMeters = 0.035f;
        [SerializeField] private float maxSegmentMeters = 80f;
        [SerializeField] private float groundOffsetMeters = 0.025f;

        private readonly List<GameObject> spawned = new List<GameObject>();
        private string lastTrackSignature;

        private void Start()
        {
            if (trackStore == null) trackStore = FindObjectOfType<PicoTrackStore>();
            if (xrOrigin == null && Camera.main != null) xrOrigin = Camera.main.transform;
            RenderCurrentTrack();
        }

        private void Update()
        {
            RenderCurrentTrack();
        }

        public void RenderCurrentTrack()
        {
            if (trackStore == null || trackStore.CurrentTrack == null) return;
            var track = trackStore.CurrentTrack;
            var signature = $"{track.id}:{track.updatedUnixMilliseconds}:{track.racingLine.Count}";
            if (signature == lastTrackSignature) return;
            lastTrackSignature = signature;

            ClearSpawned();
            if (track.racingLine.Count < 2) return;

            var origin = track.racingLine[0];
            var maxSpeed = Mathf.Max(1f, MaxSpeed(track.racingLine));
            for (var i = 0; i < track.racingLine.Count - 1; i++)
            {
                var start = ToUnityPosition(track.racingLine[i], origin);
                var end = ToUnityPosition(track.racingLine[i + 1], origin);
                var distance = Vector3.Distance(start, end);
                if (distance < 0.15f || distance > maxSegmentMeters) continue;

                var segment = GameObject.CreatePrimitive(PrimitiveType.Cube);
                segment.name = "RacingLineSegment";
                segment.transform.SetParent(transform, false);
                segment.transform.localPosition = (start + end) * 0.5f + Vector3.up * groundOffsetMeters;
                segment.transform.localRotation = Quaternion.LookRotation(end - start, Vector3.up);
                segment.transform.localScale = new Vector3(lineWidthMeters, lineHeightMeters, distance);
                ApplyColor(segment, SpeedColor(track.racingLine[i + 1].speed, maxSpeed), lineMaterialTemplate);
                spawned.Add(segment);
            }

            AddMarker("START", ToUnityPosition(track.racingLine[0], origin), Color.green);
            var finishPoint = track.lapMode == PicoLapMode.ClosedCircuit ? track.racingLine[0] : track.racingLine[track.racingLine.Count - 1];
            AddMarker("FINISH", ToUnityPosition(finishPoint, origin), Color.yellow);
        }

        private void AddMarker(string label, Vector3 position, Color color)
        {
            var marker = GameObject.CreatePrimitive(PrimitiveType.Cube);
            marker.name = label;
            marker.transform.SetParent(transform, false);
            marker.transform.localPosition = position + Vector3.up * 0.08f;
            marker.transform.localScale = new Vector3(1.1f, 0.05f, 1.1f);
            ApplyColor(marker, color, markerMaterialTemplate);
            spawned.Add(marker);
        }

        private Vector3 ToUnityPosition(PicoTrackPoint point, PicoTrackPoint origin)
        {
            const double metersPerDegreeLatitude = 111_320.0;
            var metersPerDegreeLongitude = Math.Cos(origin.latitude * Math.PI / 180.0) * metersPerDegreeLatitude;
            var east = (point.longitude - origin.longitude) * metersPerDegreeLongitude;
            var north = (point.latitude - origin.latitude) * metersPerDegreeLatitude;
            return new Vector3((float)east, 0f, (float)north);
        }

        private static float MaxSpeed(List<PicoTrackPoint> points)
        {
            var max = 0f;
            foreach (var point in points) max = Mathf.Max(max, point.speed);
            return max;
        }

        private static Color SpeedColor(float speed, float maxSpeed)
        {
            var ratio = Mathf.Clamp01(speed / Mathf.Max(maxSpeed, 1f));
            return new Color(1f - ratio, 1f, 0f, 0.92f);
        }

        private static void ApplyColor(GameObject target, Color color, Material template)
        {
            var renderer = target.GetComponent<Renderer>();
            if (renderer == null) return;
            var material = template != null ? new Material(template) : new Material(Shader.Find("Universal Render Pipeline/Unlit"));
            material.color = color;
            renderer.sharedMaterial = material;
        }

        private void ClearSpawned()
        {
            foreach (var item in spawned)
            {
                if (item != null) Destroy(item);
            }
            spawned.Clear();
        }
    }
}
