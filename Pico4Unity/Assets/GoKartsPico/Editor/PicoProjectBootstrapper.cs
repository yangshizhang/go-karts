using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace GoKartsPico.Editor
{
    public static class PicoProjectBootstrapper
    {
        private const string ScenePath = "Assets/GoKartsPico/Scenes/GoKartsPicoMain.unity";
        private const string LineMaterialPath = "Assets/GoKartsPico/Materials/RacingLineUnlit.mat";
        private const string MarkerMaterialPath = "Assets/GoKartsPico/Materials/MarkerUnlit.mat";

        [InitializeOnLoadMethod]
        private static void InitializeOnLoad()
        {
            if (Application.isBatchMode) return;
            EditorApplication.delayCall += EnsureProjectReady;
        }

        [MenuItem("GoKarts Pico/Setup Project")]
        public static void EnsureProjectReady()
        {
            EnsureFolders();
            ConfigurePlayerSettings();
            EnsureMaterials();
            EnsureScene();
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
        }

        [MenuItem("GoKarts Pico/Build Android APK")]
        public static void BuildAndroidApk()
        {
            EnsureProjectReady();
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
            var outputDir = Path.Combine(Directory.GetParent(Application.dataPath).FullName, "Builds");
            Directory.CreateDirectory(outputDir);
            var report = BuildPipeline.BuildPlayer(new[] { ScenePath }, Path.Combine(outputDir, "GoKartsPico4.apk"), BuildTarget.Android, BuildOptions.None);
            Debug.Log($"GoKarts Pico build result: {report.summary.result}, output: {report.summary.outputPath}");
        }

        private static void EnsureFolders()
        {
            CreateFolder("Assets", "GoKartsPico");
            CreateFolder("Assets/GoKartsPico", "Scenes");
            CreateFolder("Assets/GoKartsPico", "Materials");
        }

        private static void ConfigurePlayerSettings()
        {
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
            PlayerSettings.companyName = "GoKarts";
            PlayerSettings.productName = "GoKarts Pico MR";
            PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, "com.rov.gokarts.pico");
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel29;
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.stereoRenderingPath = StereoRenderingPath.Instancing;
        }

        private static void EnsureMaterials()
        {
            CreateMaterial(LineMaterialPath, new Color(0f, 1f, 0f, 0.92f));
            CreateMaterial(MarkerMaterialPath, new Color(1f, 1f, 0f, 0.85f));
        }

        private static void EnsureScene()
        {
            if (File.Exists(ScenePath))
            {
                AddSceneToBuildSettings();
                return;
            }

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            scene.name = "GoKartsPicoMain";

            var cameraObject = new GameObject("XR Camera Fallback");
            var camera = cameraObject.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = Color.black;
            camera.nearClipPlane = 0.05f;
            camera.farClipPlane = 500f;
            cameraObject.tag = "MainCamera";
            cameraObject.transform.position = new Vector3(0f, 1.7f, 0f);

            var lightObject = new GameObject("Directional Light");
            var light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.2f;
            lightObject.transform.rotation = Quaternion.Euler(50f, -30f, 0f);

            var storeObject = new GameObject("TrackStore");
            var store = storeObject.AddComponent<GoKartsPico.PicoTrackStore>();
            var importer = storeObject.AddComponent<GoKartsPico.PicoTrackJsonImporter>();

            var lineRoot = new GameObject("RacingLineRoot");
            var renderer = lineRoot.AddComponent<GoKartsPico.PicoRacingLineRenderer>();

            var inputObject = new GameObject("PicoTrackInputController");
            var input = inputObject.AddComponent<GoKartsPico.PicoTrackInputController>();

            AssignObject(renderer, "trackStore", store);
            AssignObject(renderer, "xrOrigin", cameraObject.transform);
            AssignObject(renderer, "lineMaterialTemplate", AssetDatabase.LoadAssetAtPath<Material>(LineMaterialPath));
            AssignObject(renderer, "markerMaterialTemplate", AssetDatabase.LoadAssetAtPath<Material>(MarkerMaterialPath));
            AssignObject(importer, "trackStore", store);
            AssignObject(input, "trackStore", store);
            AssignObject(input, "lineRenderer", renderer);
            AssignObject(input, "lineRoot", lineRoot.transform);
            AssignObject(input, "headTransform", cameraObject.transform);

            EditorSceneManager.SaveScene(scene, ScenePath);
            AddSceneToBuildSettings();
        }

        private static void AddSceneToBuildSettings()
        {
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
        }

        private static void CreateFolder(string parent, string child)
        {
            if (!AssetDatabase.IsValidFolder($"{parent}/{child}")) AssetDatabase.CreateFolder(parent, child);
        }

        private static void CreateMaterial(string path, Color color)
        {
            if (AssetDatabase.LoadAssetAtPath<Material>(path) != null) return;
            var shader = Shader.Find("Universal Render Pipeline/Unlit") ?? Shader.Find("Unlit/Color") ?? Shader.Find("Standard");
            var material = new Material(shader) { color = color };
            AssetDatabase.CreateAsset(material, path);
        }

        private static void AssignObject(Object target, string propertyName, Object value)
        {
            var serialized = new SerializedObject(target);
            var property = serialized.FindProperty(propertyName);
            if (property == null) return;
            property.objectReferenceValue = value;
            serialized.ApplyModifiedPropertiesWithoutUndo();
        }
    }
}
