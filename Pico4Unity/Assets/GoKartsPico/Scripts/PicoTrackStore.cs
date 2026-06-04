using System;
using System.IO;
using UnityEngine;

namespace GoKartsPico
{
    public sealed class PicoTrackStore : MonoBehaviour
    {
        public PicoTrackCollection Tracks { get; private set; } = new PicoTrackCollection();
        public PicoTrackDefinition CurrentTrack { get; private set; } = new PicoTrackDefinition();

        private string StorePath => Path.Combine(Application.persistentDataPath, "tracks.json");

        private void Awake()
        {
            Load();
        }

        public void Load()
        {
            if (!File.Exists(StorePath))
            {
                Tracks = new PicoTrackCollection();
                CurrentTrack = new PicoTrackDefinition();
                return;
            }

            var json = File.ReadAllText(StorePath);
            Tracks = JsonUtility.FromJson<PicoTrackCollection>(json) ?? new PicoTrackCollection();
            CurrentTrack = Tracks.tracks.Count > 0 ? Tracks.tracks[0] : new PicoTrackDefinition();
        }

        public void SaveCurrent(string trackName, PicoLapMode lapMode)
        {
            CurrentTrack.name = string.IsNullOrWhiteSpace(trackName) ? "未命名赛道" : trackName.Trim();
            CurrentTrack.lapMode = lapMode;
            CurrentTrack.updatedUnixMilliseconds = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            var index = Tracks.tracks.FindIndex(track => track.id == CurrentTrack.id);
            if (index >= 0) Tracks.tracks[index] = CurrentTrack;
            else Tracks.tracks.Insert(0, CurrentTrack);

            File.WriteAllText(StorePath, JsonUtility.ToJson(Tracks, true));
        }

        public void LoadTrack(PicoTrackDefinition track)
        {
            CurrentTrack = track;
        }

        public void NewTrack()
        {
            CurrentTrack = new PicoTrackDefinition();
        }
    }
}
