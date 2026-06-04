using System.IO;
using UnityEngine;

namespace GoKartsPico
{
    public sealed class PicoTrackJsonImporter : MonoBehaviour
    {
        [SerializeField] private PicoTrackStore trackStore;
        [SerializeField] private TextAsset bundledTracksJson;

        private void Awake()
        {
            if (trackStore == null) trackStore = FindObjectOfType<PicoTrackStore>();
        }

        public void ImportBundledTracks()
        {
            if (bundledTracksJson == null || trackStore == null) return;
            ImportJson(bundledTracksJson.text);
        }

        public void ImportFromPersistentPath(string fileName)
        {
            var path = Path.Combine(Application.persistentDataPath, fileName);
            if (!File.Exists(path)) return;
            ImportJson(File.ReadAllText(path));
        }

        private void ImportJson(string json)
        {
            var collection = JsonUtility.FromJson<PicoTrackCollection>(json);
            if (collection == null) return;
            trackStore.Tracks.tracks.Clear();
            trackStore.Tracks.tracks.AddRange(collection.tracks);
            if (collection.tracks.Count > 0) trackStore.LoadTrack(collection.tracks[0]);
            trackStore.SaveCurrent(trackStore.CurrentTrack.name, trackStore.CurrentTrack.lapMode);
        }
    }
}
